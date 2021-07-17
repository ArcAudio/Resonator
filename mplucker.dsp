import("stdfaust.lib");


// IIR hilbert transform Emmanuel Favreau (via Miller Puckette)
// fastest
hilbertef(x) = real(x), imag(x)
with {
  biquad(a1,a2,b0,b1,b2) = + ~ conv2(a1,a2) : conv3(b0,b1,b2) 
  with {
    conv3(k0,k1,k2,x) = k0*x + k1*x' + k2*x'';
    conv2(k0,k1,x) = k0*x + k1*x';
  };
  real = biquad(-0.02569, 0.260502, -0.260502, 0.02569, 1) 
        : biquad(1.8685, -0.870686, 0.870686, -1.8685, 1) ;
  imag = biquad(1.94632, -0.94657, 0.94657, -1.94632, 1) 
      : biquad(0.83774, -0.06338, 0.06338,  -0.83774, 1) ;
};

freqshift(x, shift) = negative(x), positive(x)
with {
  negative(x) = real(x)*cosv - imag(x)*sinv;
  positive(x) = real(x)*cosv + imag(x)*sinv;
  real(x) = hilbert(x) : _ , !;
  imag(x) = hilbert(x) : ! , _;
  
  phasor(x) = fmod((x/float(ma.SR) : (+ : ma.decimal) ~ _), 1.)  * (ma.PI * 2);

  sinv = sin(phasor(shift));
  cosv = cos(phasor(shift));

  hilbert = hilbertef;
};

ssb(shift, x) = freqshift(x, shift) : _ , !; // only take one sideband

shift = hslider("shift [knob:4]", 2.2, -20., 20, 0.001);
shift_scalar = hslider("shift_scalar[knob:5]", 6., 1., 100, 0.1);
lr_offset = hslider("lr_offset [knob:3]", 0., 0., 1., 0.00001);
fmix = hslider("fmix [knob:2]",0.0,0,1,0.01) : si.smooth(ba.tau2pole(0.005));

shift_amount = shift*shift_scalar;
shifter(l, r) = l, r <: *(1-fmix) , *(1-fmix), ssb(shift_amount ,l )*fmix , ssb(shift_amount +lr_offset,r )*fmix :> _,_ ;

myString(length,pluckPos,excite) = pm.endChain(myChain)
with {
    stringL = length-0.11;
    stiffness = hslider("stiffness",0.3,0,1,0.01) : si.smoo ;
    myChain = pm.chain(pm.elecGuitarNuts : pm.openStringPick(stringL,stiffness,pluckPos,excite) : pm.elecGuitarBridge);
};

//l = hslider("freq",200,20,1000,0.01) : pm.f2l : si.smoo;
l = ba.midikey2hz(base) : pm.f2l;
l2 = ba.midikey2hz(base+freq1) : pm.f2l;
l3 = ba.midikey2hz(base+freq2) : pm.f2l;
l4 = ba.midikey2hz(base+freq3) : pm.f2l;
//l2 = hslider("freq2",400,100,1000,0.01) : pm.f2l : si.smoo;

level = hslider("level",0.3,0.0,0.5,0.01) : si.smoo;

filterlevel = hslider("filterlevel",0.1,0.0,0.3,0.01) : si.smoo;
//l = 1.0;
excitation = hslider("excitation",1,0,1,0.01) : si.smoo;
base = hslider("base",50,10,120,1):si.smoo;
freq1 = hslider("freq1",0,0,24,1):si.smoo;
freq2 = hslider("freq2",3,0,24,1):si.smoo;
freq3 = hslider("freq3",7,0,24,1):si.smoo;
freq4 = hslider("freq4",9,0,24,1):si.smoo;
stringer = (myString(l,excitation) *level,myString(l2,excitation) *level,myString(l3,excitation) *level,myString(l4,excitation) *level);

// gate, freq (pitch), gain parameters
gate = button("gate"); 
freq = hslider("freq[unit:Hz]", 440, 20, 20000, 1);
gain = hslider("gain", 0.5, 0, 10, 0.01);

// Filter Parameters
ctFreq = hslider("ctFreq",500,20,10000,0.01) : si.smoo;
filterQ = hslider("filterQ", 5, 0, 10, 1);
filterGain = hslider("filterGain",1,0,1,0.01) : si.smoo;

// Parameters for the harmonic oscillator
harmonic(rang) = os.saw2f4(freq)*volume
    with {
        // UI
        vol = hslider("vol%rang", 1, 0, 1, 0.001) : si.smooth(ba.tau2pole(0.01));
     
        a = 0.01 * hslider("A%rang", 1, 0, 400, 0.001) : si.smoo;
        d = 0.01 * hslider("D%rang", 1, 0, 400, 0.001) : si.smoo;
        s = hslider("S%rang", 1, 0, 1, 0.001) : si.smoo;
        r = 0.01 * hslider("R%rang", 1, 0, 800, 0.001) : si.smoo;

        volume = ((en.adsr(a,d,s,r,gate))*vol) : max (0) : min (1);
    };

selectInput = hgroup("[0]inputSelect",(par(i, 8, harmonic(i)) :> / (8)) , (_<:  stringer :>_)  : ba.selectn(2,input))
with{
    input = nentry("input",1,0,1,1);
};

dmix = hslider("dmix [knob:4]", 0.55, 0, 1, 0.01) : si.smooth(ba.tau2pole(0.005));
echof(l) =  l<: *(1-dmix),  +~(de.fdelay4(maxDelLength,delLength-1) : *(feedback))*dmix :> _;

duration = hslider("duration [knob:1]", 200,1,200,1)*0.001 :  si.smoo;
feedback = hslider("feedback [knob:2]", 0.8, 0 , 1.0 ,0.01);//
//damping =  hslider("Damping", 0.99,0,1,0.01);
filter = _ <: _,_ ' :> / (2);
maxDelLength = 12000;
delLength = ma.SR*duration;

process = + <: stringer :> shifter(_,_) : echof(_) ,echof(_) ;