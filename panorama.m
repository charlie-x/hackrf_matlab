function panorama
% PANORAMA is a simple spectrum analyzer gui for the hackRF
%
%   Tillmann Stuebler, 21-02-2016
%

    function callback(g,~)
        % callback function for all gui controls
        
        if strcmp(get(g,'Style'),'popupmenu')
            s=get(g,'String');
            v=get(g,'Value');
            v=str2double(s(v,:));
        end
        
        switch g
            case freqed
                changefreq(str2double(get(g,'String')));
            case rxbut
                if get(g,'Value')
                    h.rxStart;
                else
                    h.rxStop;
                end
            case srpop
                h.SampleRate=v;
            case bwpop
                h.Bandwidth=v;
            case lnapop
                h.lnaGain=v;
            case vgapop
                h.vgaGain=v;
        end
        
    end

    function clickcallback(~,e)
        if e.Button==1
            changefreq(e.IntersectionPoint(1));
            v=str2double(cellstr(get(bwpop,'String')));
            k=find(v==h.Bandwidth);
            k=k+1-2*strcmp(z.Direction,'in');
            k=min(numel(v),max(1,k));
            h.Bandwidth=v(k);
            set(bwpop,'Value',k);
        end
    end

    function changefreq(fnew)
        deltaf=fnew-h.Frequency;
        h.Frequency=fnew;
        freqed.String=num2str(h.Frequency);
        m=circshift(m,-round(n*deltaf/diff(im.XData)),2);
    end

    function shutdown(~,~)
        delete(h);
    end

    function panprecallback(~,~)
        panning=true;
    end

    function panpostcallback(~,~)
        panning=false;
        changefreq(mean(xlim(a)));
    end

    function rxcallback(~,z)
        [q,r]=rat(max(1,h.SampleRate/h.Bandwidth/2),.1);
        o=floor(n*q/r);
        
        buf=[buf;z*h.GainScalar];
        
        if numel(z)>=1e4
            adte.String=sprintf('max abs %2.0f%%',1e2*max(abs([real(z(1:1e4));imag(z(1:1e4))])));
        end
        
        K=floor(numel(buf)/N);
        m=[zeros(K,size(m,2));m];
        for i=1:K
            Z=buf((i-1)*N+(1:o));
            Z=resample(Z,r,q);
            Z=log(abs(fftshift(fft(win.*Z))));
            m(K+1-i,:)=20/exp(1)*Z';
            
        end
        buf(1:N*floor(end/N))=[];
        
        m(D:end,:)=[];
        
        if ~(panning || isempty(m))
            
            xl=h.Frequency+r/q/2*[-1 1]*h.SampleRate;
            xd=linspace(xl(1),xl(2),n);
            
            mm=median(m,1);
            
            s1=min(mm);
            s2=max(mm);
            
            M=round(h.SampleRate/N);
            
            li1.XData=xd;
            li1.YData=median(m(1:min(end,M),:));
            
            li2.XData=xd;
            li2.YData=mm';
            
            im.CData=m;
            im.XData=xl;
            im.YData=[s1 s2];
            
            axis([h.Frequency+[-1 1]/2*h.Bandwidth s1 s2]);
            
        end
    end

h=hackrf;
h.ReceiveFcn=@rxcallback;

buf=[]; % empty receive buffer

N=1e6; % will make one fft every N samples
n=1024; % will make n-point fft
win=gausswin(n); % window function

m=zeros(0,n); % empty waterfall display buffer
D=2e2; % number of lines to display

f=figure('Name','panorama','DeleteFcn',@shutdown);

% will capture pan callbacks and tune to the appropriate frequency
% interactively
p=pan(f);
p.Enable='on';
p.Motion='horizontal';
p.ActionPostCallback=@panpostcallback;
p.ActionPreCallback=@panprecallback;
panning=false;

% will capture zoom callbacks and change frequency/bandwidth
z=zoom(f);
z.ButtonDownFilter=@(~,~)true;

% prepare display
a=axes('Parent',f,'Position',[.05 .25 .9 .7]);
a.ButtonDownFcn=@clickcallback;

% image object for waterfall display
im=image('Parent',a,'CDataMapping','scaled');
im.HitTest='off';
hold(a,'on');

% line for fft average
li2=plot(a,zeros(1,n),zeros(1,n));
li2.Color='b';
li2.LineWidth=2;
li2.HitTest='off';

% line for actual fft
li1=plot(a,zeros(1,n),zeros(1,n));
li1.Color='k';
li1.HitTest='off';

hold(a,'off');

uicontrol(f,'Style','text','String','frequency:','Position',[10 40 100 20]);
freqed=uicontrol(f,'Style','edit','Position',[120 40 100 20],'Callback',@callback);

rxbut=uicontrol(f,'Style','togglebutton','String','rx','Position',[10 10 100 20],'Callback',@callback);
adte=uicontrol(f,'Style','text','Position',[120 10 100 20]);

uicontrol(f,'Style','text','String','sample rate:','Position',[230 40 100 20]);
srpop=uicontrol(f,'Style','popupmenu','Position',[340 40 100 20],'String',num2str([8e6 10e6 12.5e6 16e6 20e6]','%g'),'Callback',@callback);

uicontrol(f,'Style','text','String','bandwidth:','Position',[230 10 100 20]);
bwpop=uicontrol(f,'Style','popupmenu','Position',[340 10 100 20],'String',num2str([1.75e6 2.5e6 3.5e6 5e6 5.5e6 6e6 7e6 8e6 9e6 10e6 12e6 14e6 15e6 20e6 24e6 28e6]','%g'),'Callback',@callback);

uicontrol(f,'Style','text','String','lna gain:','Position',[450 40 100 20]);
lnapop=uicontrol(f,'Style','popupmenu','Position',[560 40 100 20],'String',num2str((0:8:40)'),'Callback',@callback);

uicontrol(f,'Style','text','String','vga gain:','Position',[450 10 100 20]);
vgapop=uicontrol(f,'Style','popupmenu','Position',[560 10 100 20],'String',num2str((0:2:62)'),'Callback',@callback);


end