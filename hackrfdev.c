/*
 * this is simply a c-mex gateway for the hackrf library
 * Tillmann Stübler, 14-02-2016
 */

#include "mex.h"
#include <stdio.h>
#include <libhackrf/hackrf.h>

/* buffer length for rx and tx */
#define buflen 40000000

static hackrf_device* device = NULL;
static char is_hackrf_open = 0;

static int8_t buf[buflen];
static uint32_t wptr,rptr;

int rx_callback(hackrf_transfer *transfer)
{
    uint32_t i;
    
    for(i=0;i<transfer->valid_length;i++) {
        buf[(wptr+i)%buflen]=transfer->buffer[i];
    }
    wptr=(wptr+transfer->valid_length)%buflen;
    
    return 0;
}



int tx_callback(hackrf_transfer* transfer)
{
    uint32_t i;
    
    for(i = 0;i<transfer->valid_length;i++) {
        transfer->buffer[i] = buf[(rptr+i)%buflen];
    }
    rptr=(rptr+transfer->valid_length)%buflen;
    
    return 0;
}



void closedevice(void)
{
    if(is_hackrf_open) {
        mexPrintf("closing...\n");
        hackrf_close(device);
    }
}

mxArray * getdata(void)
{
    mxArray * p;
    int8_t *x,*y;
    uint32_t n,i;
    
    n=((wptr-rptr+buflen)%buflen)/2;
    
    p=mxCreateNumericMatrix(n,1,mxINT8_CLASS,mxCOMPLEX);
    x=mxGetData(p);
    y=mxGetImagData(p);
    
    for(i=0;i<n;i++) {
        x[i]=buf[(rptr+2*i)%buflen];
        y[i]=buf[(rptr+2*i+1)%buflen];
    }
    rptr=(rptr+2*n)%buflen;
    
    return p;
}

void putdata(const mxArray* p)
{
    int8_t *x,*y;
    uint32_t n,i;
    
    n=mxGetNumberOfElements(p);
    
    x=mxGetData(p);
    y=mxGetImagData(p);
    
    for(i=0;i<n;i++) {
        buf[(wptr+2*i)%buflen]=x[i];
        buf[(wptr+2*i+1)%buflen]=y[i];
    }
    wptr=(wptr+2*n)%buflen;
    
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    char cmd[32];
    char s[32];
    double * p;
    
    
    mexAtExit(closedevice);
    
    if(nrhs>0) {
        mxGetString(prhs[0],cmd,32);
        
        if(nrhs>1 && strcmp("data",cmd)) {
            p=mxGetPr(prhs[1]);
            mexPrintf("param: %i\n",(uint32_t) p[0]);
        }
        
        if(strcmp(cmd,"open")==0) {
            mexPrintf("try to init...\n");
            if(hackrf_init()!=0)
            {
                mexErrMsgTxt("Error in hackrf_init()");
            }
            
            if(hackrf_open(&device)!=0)
            {
                mexErrMsgTxt("Error in hackrf_open()");
            }
            
            is_hackrf_open=1;
            
        } else if(strcmp("close",cmd)==0) {
            mexPrintf("try to close...\n");
            if(hackrf_close(device)!=0) {
                mexErrMsgTxt("Error in hackrf_close()");
            }
            is_hackrf_open=0;
        } else if(strcmp("frequency",cmd)==0) {
            if(hackrf_set_freq(device, (uint64_t) p[0])!=0) {
                mexErrMsgTxt("Error in hackrf_set_freq()");
            }
        } else if(strcmp("samplerate",cmd)==0) {
            if(hackrf_set_sample_rate(device, (uint32_t) p[0])!=0) {
                mexErrMsgTxt("Error in hackrf_set_sample_rate()");
            }
        } else if(strcmp("amp",cmd)==0) {
            if(hackrf_set_amp_enable(device, (uint8_t) p[0])!=0) {
                mexErrMsgTxt("Error in hackrf_set_amp_enable()");
            }
        } else if(strcmp("lna",cmd)==0) {
            if(hackrf_set_lna_gain(device, (uint32_t) p[0])!=0) {
                mexErrMsgTxt("Error in hackrf_set_lna_gain()");
            }
        } else if(strcmp("vga",cmd)==0) {
            if(hackrf_set_vga_gain(device, (uint32_t) p[0])!=0) {
                mexErrMsgTxt("Error in hackrf_set_vga_gain()");
            }
        } else if(strcmp("txvga",cmd)==0) {
            if(hackrf_set_txvga_gain(device, (uint32_t) p[0])!=0) {
                mexErrMsgTxt("Error in hackrf_set_txvga_gain()");
            }
        } else if(strcmp("bandwidth",cmd)==0) {
            if(hackrf_set_baseband_filter_bandwidth(device, (uint32_t) p[0])!=0) {
                mexErrMsgTxt("Error in hackrf_set_baseband_filter_bandwidth()");
            }
        } else if(strcmp("start_rx",cmd)==0) {
            
            wptr=0;
            rptr=0;
            
            if(hackrf_start_rx(device, rx_callback, NULL)!=0) {
                mexErrMsgTxt("Error in hackrf_start_rx()");
            }
            
        } else if(strcmp("stop_rx",cmd)==0) {
            
            if(hackrf_stop_rx(device)!=0) {
                mexErrMsgTxt("Error in hackrf_stop_rx()");
            }
            
        } else if(strcmp("start_tx",cmd)==0) {
            
            wptr=0;
            rptr=0;
            
            if(hackrf_start_tx(device, tx_callback, NULL)!=0) {
                mexErrMsgTxt("Error in hackrf_start_tx()");
            }
            
        } else if(strcmp("stop_tx",cmd)==0) {
            
            if(hackrf_stop_tx(device)!=0) {
                mexErrMsgTxt("Error in hackrf_stop_tx()");
            }
            
        } else if(strcmp("data",cmd)==0) {
            if(nlhs>0) {
                plhs[0]=getdata();
            } else if(nrhs>1) {
                putdata(prhs[1]);
            }
        } else if (strcmp("number_of_samples_to_write",cmd)==0) {
            if(nlhs>0) {
                plhs[0]=mxCreateDoubleScalar((((rptr-wptr+buflen-1)%buflen)+1)/2);
            }
        } else if(strcmp("board_id",cmd)==0) {
            if(hackrf_board_id_read(device,s)!=0) {
                mexErrMsgTxt("Error in hackrf_board_id_read()");
            }
            if(nlhs>0) {
                plhs[0]=mxCreateDoubleScalar(s[0]);
            }
        } else if(strcmp("version",cmd)==0) {
            if(hackrf_version_string_read(device,s,31)!=0) {
                mexErrMsgTxt("Error in hackrf_version_string_read()");
            }
            if(nlhs>0) {
                plhs[0]=mxCreateString(s);
            }
        } else if(strcmp("is_open",cmd)==0) {
            if(nlhs>0) {
                plhs[0]=mxCreateDoubleScalar(is_hackrf_open);
            }
        } else {
            mexPrintf("Unknown command: %s\n",cmd);
        }
        
    } else {
        mexErrMsgTxt("Wrong number of input/output arguments.");
    }
    
}