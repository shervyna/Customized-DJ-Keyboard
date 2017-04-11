/*
Ruan Hsuan Wei and Rebekah Kim
CPSC 134 Programming Music Applications
Final Project
-----------------
The main purpose for our project is to customize sets of DJ effects on a MIDI keyboard, and allow users to import and remix songs from Spotify. Currently we have piano, saxphone, some random samples, and drum pads. People can easily customize their samples by changing the sample files in the assigned path. This will work best if we use voice-only pieces of music (like instrumental tracks), or cut those tracks to the parts where you want to import them.
*/
ServerOptions.devices
//set the audio I/O to SoundFlower
//need to download SoundFlower and do the settings on MIDI setup first
Server.local.options.device = "Aggregate Device";
s.makeGui;
(
//connect midi devices(keyboard)
MIDIIn.connectAll;
MIDIFunc.trace;

//read samples from files by putting the path in arrays and read it later when triggered by the midi keyboard
//remember to change the path
~samp = Array.new;
~folder= PathName.new("/Users/shervyna/Desktop/realrealsamps/");
(
~folder.entries.do({
	arg path;
	~samp= ~samp.add(Buffer.read(s,path.fullPath));
});
);
// same thing for the drum samples, because some of the numbers(38~49) on the drumpad(on the side of the keyboard, channel 9) overlap with the normal effects on keyboard(36~82), we separated it by putting the path for drum effects in different sample arrays
~drum= Array.new;
~folder= PathName.new("/Users/shervyna/Desktop/drums/");
(
~folder.entries.do({
	arg path;
	~drum= ~drum.add(Buffer.read(s,path.fullPath));
});
);

//synthdefs

(//piano and pitch bend
   SynthDef( \piano, { |freq=500, gate=0, velocity=100, out=0, amp=0.5, bend=0|
	var sig, env;
	sig= SinOsc.ar(freq * bend.midiratio) !2;// when pitch bend not triggered, it plays normal piano sound
	env= EnvGen.kr(Env.adsr, gate, velocity, doneAction: 2);
	sig= sig * env * amp;
	Out.ar(0, sig);
    }).add;
);
(//normal effects and drum effects call this synthdef to play effects. We only use samples that are 2 channels to avoid errors.
SynthDef(\effects2,{arg out =0, bufnum,gate=0,velocity=100;
	var sig, env;
	sig= PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum));
	env= EnvGen.kr(Env.adsr(0.01,0.3,0.5,2,1,-4,0), gate, velocity, doneAction:2);
	sig = sig * env ;
		Out.ar(0, sig, sig);
}).add;
);
(//saxphone
SynthDef(\sax, { |out, freq=440, amp=0.1, gate=1|
	var num = 16;
	var harms = Array.series(num, 1, 1) * Array.exprand(num, 0.995, 1.001);
	var snd = SinOsc.ar(freq * SinOsc.kr(Rand(2.0,5.0),0,Rand(0.001, 0.01),1) * harms, mul:Array.geom(num, 1, 0.63));
	snd = Splay.ar(snd);
	snd = BBandPass.ar(snd, freq * XLine.kr(0.1,4,0.01), 2);
	snd = snd * amp * EnvGen.ar(Env.adsr(0.001, 0.2, 0.7, 0.2), gate, doneAction:2);
	Out.ar(out, snd!2);
}).add;
);
(//import music
SynthDef(\playmusic, {arg gate=0;
    var snd, filter;
	snd = SoundIn.ar([0,1],2); // this is an array of two channels
	Out.ar(0, snd*EnvGen.kr( Env.adsr, gate,1, doneAction:2));
}).add;
);
(//add radio filter
  SynthDef(\filter, {arg gate=0;
	var snd, filter,pan;
	snd = Mix.new(SoundIn.ar([0,1]),2);
	filter = RLPF.ar(snd,700, 0.1, 1);
	pan=Pan2.ar(filter*EnvGen.kr( Env.adsr, gate,1, doneAction:2),MouseX.kr(-1,1));//control panning with mouse
	Out.ar(0, pan);
  }).add;
);
(//the whistle dropping effect
SynthDef(\freeverb, {|mix = 0.7, room = 2, damp = 1, gate=0,velocity=0.5|
    Out.ar(0,
        FreeVerb.ar(
			SinOsc.ar(XLine.kr(1500,300,1.5)),
            mix, // mix 0-1
            room, // room 0-1
            damp // damp 0-1
        )*EnvGen.kr( Env.adsr, gate,velocity, doneAction:2)
    );
}).add;
);

~drumeffects = IdentityDictionary.new;//for drums
~effects = IdentityDictionary.new;//for effects
~melody = IdentityDictionary.new; //for melody
~flag=1;// to switch between melody and effect
// we orginally had the switching between different sets of effects feature where a different set of effects is assigned to the keyboard when a key is triggered. For people who have a smaller range of keys on their midi device, they can take off the commented part and use the feature.

(
MIDIdef.noteOn( \akaiPad1On, { arg val, num;
	/*if(num==83){ // if switch key(end of the mini keyboard) pressed, change currect status
				~flag=~flag+1;
				~flag=~flag%2;
	}{//if keys other than the switch status key pressed(to prevent unneccessary sound when switch status)
	*/
		if(~flag==1){ // because we are not using the switch status feature in our project, flag will always be 1 and this statement will always be true
		case
			{num==36}{// import  music
				"music added".postln;
				~effects.put( num, Synth.new( \playmusic,[\gate,1]) );
			}
			{num==37}{ //radio effect
				~effects.at(36).set(\gate,0);
				"normal music free and add radio".postln;
				~effects.put( num, Synth.new( \filter,[\gate,1]) );
			}
			{num==38}{// the whistle dropping effect
				~effects.put( num, Synth.new( \freeverb,[\gate,1,\velocity, val/100]) );
			}
			{(num>46)&&(num<60)}{ // a range of saxphone effects
				~effects.put( num, Synth.new( \sax,[\gate,1,\amp,0.7,\freq,(num+12).midicps]) );
			}
			{(num>38)&&(num<47)}{ //a range of effects
					~effects.put( num, Synth.new( \effects2,[\bufnum,~samp[(num)%9].bufnum,\gate,1,\velocity,val/70] ) );

			}
			{
			"melody".postln;// a range of piano effects( any key above 60)
			~melody.put( num, Synth.new( \piano , [\gate, 1, \velocity, val/100, \freq, (num+14).midicps, \bend, val.linlin(0, 16383, -2, 2 )] ) );
			}
		}
		{}
	}
//}
, (0..127), 0, -1651158224);//remember to change src according to different computers or devices

);

(//assigning particular drum effects to each pad, we assigned the effects that would make it easy to for us to play
MIDIdef.noteOn( \drumpad, {arg val,num;
	case
	{(num>35) && (num<40)}{num=(num%36);}
	{num==41}{num=4;}
	{num==42}{num=5;}
	{num==46}{num=6;}
	{num==49}{num=7;};
	~drumeffects.put( num, Synth.new(\effects2,[\bufnum,~drum[num].bufnum,\gate, 1, \velocity, val/10]);
 );
}, (36..49), 9, -1651158224);// channel 9, the drum pads only

//free drum synths
MIDIdef.noteOff(\drumpadoff, {arg val,num;
	case
	{(num>35) && (num<40)}{num=(num%36);}
	{num==41}{num=4;}
	{num==42}{num=5;}
	{num==46}{num=6;}
	{num==49}{num=7;};
	~drumeffects.at(num).set(\gate,0);}, (36..49), 9, -1651158224);
);

(//free effect synths
MIDIdef.noteOff( \akaiPad1Off, {
	arg val, num;
			case
			{num==36}{}
			{num==37}{// adding back normal music when the radio effect is freed
				"radio free".postln;
				~effects.at(37).set(\gate,0);
				"normal music return".postln;
				~effects.put( 36, Synth.new( \playmusic,[\gate,1]) );
			}
	       {num<60}{
				~effects.at(num).set(\gate,0);
			}

	{			~melody.at( num ).set( \gate, 0 );
}
}, (0..127), 0,  -1651158224 );

);

~bend= 8192;

//pitch bend
MIDIdef.bend(\bendTest, {// will cause error but can ignore it
	arg val;
	~bend = val;
	~melody.do{arg synth; synth.set(\bend, val.linlin(0, 16383, -2, 2))};
},0, -1651158224);


//if any control key pressed, it shifts to next song on spotify
MIDIFunc.cc( { arg num;
		"osascript -e 'tell application \"Spotify\" to next track'".unixCmd;}//applescript
);


)
