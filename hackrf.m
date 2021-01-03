classdef hackrf<handle
    % HACKRF construct hackrf object.
    %
    %   The hackrf object is merely a wrapper for the hackrf library to
    %   receive and transmit signals directly from matlab. It
    %   allows uninterrupted transfers to and from the hackrf without
    %   storing signals on disk intermediately.
    %
    %   You can access parameters like frequency, sample rate, bandwidth,
    %   and gain settings. To transmit/receive, you need to provide
    %   callback functions:
    %   z=TransmitFcn(hackrfObj, numberOfSamplesToTransmit)
    %   ReceiveFcn(hackrfObj, z)
    %   where z is a vector of complex samples.
    %   For transmission, it can be an integer vector in the range
    %   [-127, 127], or a single or double vector in the range [-1, 1].
    %   For reception, the samples are casted to a user-selectable data
    %   type. By default, data type is double and values are in the range
    %   [-1, 1]. Alternatively, you can set rxNumericType to 'int8'.
    %
    %   Currently, it is not supported to use multiple hackRF devices at the
    %   same time! Creating more than one instance of the hackrf class
    %   will give strange behaviour.
    %
    %   Be aware that when using this object, unplugging the hackRF from
    %   the USB port will likely kill MATLAB!
    %
    %   Internals: the mex functions uses a receive/transmit buffer of
    %   40MB, which is enough to keep between 1 and 2.5 seconds of complex
    %   samples, depending on sample rate. The callback executes every
    %   half second.
    %
    %   Tillmann Stübler, 20-02-2016
    %
    
    properties (Dependent)
        IsOpen % is hackrf device open?
        BoardId % hackrf board id
        Version % hackrf board version
        SamplesToWrite % for tx, number of samples the buffer can receive now
        GainScalar % gives the reciprocal scalar gain factor resulting from the current gain settings
    end
    
    properties (SetObservable)
        Frequency % hackrf rx/tx frequency
        SampleRate % hackrf sample rate
        Bandwidth % hackrf filter bandwidth
        lnaGain % rx low noise amplifier gain
        vgaGain % rx baseband gain
        txvgaGain % tx baseband gain
        AmpEnable % enable rx/tx amplifier
        ReceiveFcn % receive callback function
        TransmitFcn % transmit callback function
        rxNumericType='double' % numeric type of RX samples
    end
    
    properties (GetAccess=public, SetAccess=private)
        rx=false
        tx=false
    end
    
    properties (Access=private)
        trxtimer % timer to execute rx/tx callback functions
    end
    
    methods
        
        function obj=hackrf
            obj.trxtimer=timer('ExecutionMode','fixedDelay','Period',.5,'TimerFcn',@(~,~)obj.trxcallback);
            open(obj);
            obj.AmpEnable=0;
            obj.lnaGain=0;
            obj.vgaGain=0;
            obj.txvgaGain=0;
            obj.Frequency=1e8;
            obj.SampleRate=8e6;
            obj.Bandwidth=1.75e6;
        end
        
        function delete(obj)
            stop(obj.trxtimer);
            delete(obj.trxtimer);
            close(obj);
        end
        
        function o=get.IsOpen(~)
            % check if hackrf device is open
            o=hackrfdev('is_open');
        end
        
        function i=get.BoardId(obj)
            % get hackrf board id
            if obj.IsOpen
                i=hackrfdev('board_id');
            else
                i=[];
            end
        end
        
        function v=get.Version(obj)
            % get hackrf board version
            if obj.IsOpen
                v=hackrfdev('version');
            else
                v=[];
            end
        end
        
        function v=get.SamplesToWrite(obj)
            % get the number of samples the buffer can receive for tx
            if obj.IsOpen
                v=hackrfdev('number_of_samples_to_write');
            else
                v=[];
            end
        end
        
        function s=get.GainScalar(obj)
            % get the reciprocal receive gain factor resulting from the current gain settings
            
            s=10^(-(obj.lnaGain+obj.vgaGain+13*obj.AmpEnable)/20);
        end
        
        function set.Frequency(obj,f)
            % check if frequency is feasible, and send the appropriate
            % command to the hackrf
            if isnumeric(f) && isscalar(f) && f>=0 && f<=7250e6
                f=round(f);
                obj.Frequency=f;
                hackrfdev('frequency',f);
            end
        end
        
        function set.SampleRate(obj,s)
            % check if sample rate is feasible, and send the appropriate
            % command to the hackrf
            if isnumeric(s) && isscalar(s) && ismember(s,[8e6 10e6 12.5e6 16e6 20e6])
                obj.SampleRate=s;
                hackrfdev('samplerate',s);
            end
        end
        
        function set.Bandwidth(obj,b)
            % check if bandwidth is feasible, and send the appropriate
            % command to the hackrf
            if isnumeric(b) && isscalar(b) && ismember(b,[1.75e6 2.5e6 3.5e6 5e6 5.5e6 6e6 7e6 8e6 9e6 10e6 12e6 14e6 15e6 20e6 24e6 28e6])
                obj.Bandwidth=b;
                hackrfdev('bandwidth',b);
            end
        end
        
        function set.lnaGain(obj,g)
            % check if lna gain is feasible, and send the appropriate
            % command to the hackrf
            if isnumeric(g) && isscalar(g) && ismember(g,0:8:40)
                obj.lnaGain=g;
                hackrfdev('lna',g);
            end
        end
        
        function set.vgaGain(obj,g)
            % check if vga gain is feasible, ans send the appropriate
            % command to the hackrf
            if isnumeric(g) && isscalar(g) && ismember(g,0:2:62)
                obj.vgaGain=g;
                hackrfdev('vga',g);
            end
        end
        
        function set.txvgaGain(obj,g)
            % check if txvga gain is feasible, and send the appropriate
            % command to the hackrf
            if isnumeric(g) && isscalar(g) && ismember(g,0:47)
                obj.txvgaGain=g;
                hackrfdev('txvga',g);
            end
        end
        
        function set.AmpEnable(obj,a)
            % check if value is feasible, and send the appropriate command
            % to the hackrf
            if (isnumeric(a) || islogical(a)) && isscalar(a)
                a=a>0;
                obj.AmpEnable=a;
                hackrfdev('amp',a);
            end
        end
        
        function set.rxNumericType(obj,t)
            if ~isnumerictype(t)
                error('''%s'' is not supported.\nIt would make sense to chose either ''double'', ''single'', or ''int8''.',t);
            end
            obj.rxNumericType=t;
        end
        
        function open(obj)
            % open hackrf device
            if ~obj.IsOpen
                hackrfdev open
            else
                warning('hackrf device is already open.');
            end
        end
        
        function close(obj)
            % close hackrf device
            if obj.IsOpen
                hackrfdev close
            else
                warning('hackrf device is not open.');
            end
        end
        
        function rxStart(obj)
            % start receiving.
            % re-open device first
            if obj.IsOpen
                hackrfdev close
            end
            hackrfdev open
            hackrfdev start_rx
            obj.rx=true;
            start(obj.trxtimer);
        end
        
        function rxStop(obj)
            % stop receiving.
            hackrfdev stop_rx
            obj.rx=false;
        end
        
        function txStart(obj)
            % start transmitting.
            % re-open device first
            if obj.IsOpen
                hackrfdev close
            end
            hackrfdev open
            hackrfdev start_tx
            obj.tx=true;
            start(obj.trxtimer);
        end
        
        function txStop(obj)
            % stop transmitting.
            hackrfdev stop_tx
            obj.tx=false;
        end
        
    end
    
    methods (Access=private)
        
        function trxcallback(obj)
            % call the user-supplied rx or tx function
            
            if obj.rx
                z=hackrfdev('data');
                if ~isempty(obj.ReceiveFcn) && ~isempty(z)
                    z=cast(z,obj.rxNumericType);
                    if ismember(obj.rxNumericType,{'single' 'double'})
                        z=z./128;
                    end
                    feval(obj.ReceiveFcn,obj,z);
                end
            elseif obj.tx
                if ~isempty(obj.TransmitFcn)
                    z=feval(obj.TransmitFcn,obj,obj.SamplesToWrite);
                    if isfloat(z)
                        z=127*z;
                    end
                    hackrfdev('data',int8(z));
                end
            else
                stop(obj.trxtimer);
            end
            
        end
        
    end
    
end