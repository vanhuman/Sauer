// Sauer/Tenney hybrid organ
// Robert van Heumen (c) 2015
// Build for the Orgelpark Symposium June 4-6 2015

(
s.waitForBoot {

	var wSauerTenney, s2dSauer, s2dSauerLabel, s2dTenney, s2dTenneyLabel;
	var tenneyEnabled = 0, sauerEnabled = 0, registerSelectNew, registerSelect;
	var notes = Array.newClear(128);
	var cBus = (
		modfreq: Bus.control(s,1).set(0.5), filterfreq: Bus.control(s,1).set(0.5)
	);
	var spec = (
		modfreq: ControlSpec(5000,5,\exp),
		volume: ControlSpec(5,500, \lin),
		filterfreqBase: ControlSpec(5,15000,\exp),
		filterfreqOffset: ControlSpec(0.9,1.1,\lin),
	);

	var sauer = (
		noteChord: [5,0,2,7], // [0,1,11,19], // [0,5,7,8,10,8,7,5,7], //[0,1,2,1]
		specRepVal: Env.new([0.1,1,2],[0.5,0.5],[\lin]), // repetiton range
		specNoteLen: Env.new([0.1,5],[1.0],[\lin]), // note length range
		//	specNoteNbr: Env.new([36,81],[127],[\lin]), // note nbr range
		specNoteNbr: Env.new([24,36,48,60,72],[32,32,32,32],[\step]), // note nbr range
		specRegSelect: Env.new([1,2,20,20.9],[6,116,6],[\lin]),
		chanEx3dPro: 1, // MIDI channel for notes
		//	assignmentList: [68,70,72,75], // list of MIDI notes that switch on assignments to manual II on channel 2 (0-15)
		//	assignmentList: [67,68,69,70,71,72,73,74,75,76], // manual II with ^ and V
		//	assignmentList: [52,54,56,59], // for manual I on channel 1 (0-15)
		assignmentList: [51,52,53,54,55,56,57,58,59,60], // manual I with ^ and V
		chanRegNbr: 13, // MIDI channel for registration and assignment selection
		regList: [14,20,13,12,19,18,11,10,17,16,9,8,7,3,6,5,4,2,1,0,15],
		// list of registrations to switch on/off, should be array of 21 of which the last one is never ON
		resetNote: 101,
		deBug: 1
	);

	// --------------------------------------------- synthdefs ---------------------------------------------------

	SynthDef.new(\noise_ampmod,{
		arg gate = 1, modfreqBus, filterfreqBus, filterfreqBase;
		var sig, modfreq, filterfreqOffset, vol = 5;

		// modfreq = MouseY.kr(5000,5,1,0);
		// filterfreq = MouseX.kr(5,15000,1);

		modfreq = spec.modfreq.map(In.kr(modfreqBus,1));
		filterfreqOffset = spec.filterfreqOffset.map(In.kr(filterfreqBus,1));
		filterfreqBase = spec.filterfreqBase.map(filterfreqBase);
		// vol = spec.volume.map(In.kr(filterfreqBus,1));

		sig = SinOsc.ar(modfreq) *
		BPF.ar(ClipNoise.ar(1),filterfreqBase*filterfreqOffset,0.01) *
		EnvGen.kr(Env.adsr(1,0,1,1.0), gate, doneAction: 2);

		sig = Pan2.ar(sig, 0);

		Out.ar(0, sig * vol);
	}).send(s);


	SynthDef.new(\saw_ampmod,{
		arg gate = 1, modfreqBus, filterfreqBus, filterfreqBase;
		var sig, modfreq, filterfreqOffset, sawfreq = 200;

		modfreq = spec.modfreq.map(In.kr(modfreqBus,1));
		filterfreqOffset = spec.filterfreqOffset.map(In.kr(filterfreqBus,1));
		filterfreqBase = spec.filterfreqBase.map(filterfreqBase);
		sawfreq = (filterfreqBase * 127).midicps;

		sig = SinOsc.ar(modfreq) *
		BPF.ar(Saw.ar(sawfreq),filterfreqBase*filterfreqOffset,0.01) *
		EnvGen.kr(Env.adsr(1,0,1,1.0), doneAction: 2);

		sig = Pan2.ar(sig, Rand(1,-1));

		Out.ar(0, sig);
	}).send(s);


	SynthDef.new(\dust_ampmod,{
		arg gate = 1, modfreq, filterfreq;
		var sig, env1, ampl, dustfreq = 100;

		modfreq = MouseY.kr(5000,5,1,0);
		filterfreq = MouseX.kr(5,15000,1);

		sig = SinOsc.ar(modfreq) *
		BPF.ar(Dust.ar(dustfreq),filterfreq,0.01) *
		EnvGen.kr(Env.adsr(1,0,1,1.0), doneAction: 2);

		sig = Pan2.ar(sig, Rand(1,-1));

		Out.ar(0, sig);
	}).send(s);

	SynthDef.new(\reverb1,{
		var decay_time, delay_scale, sig;

		sig = SoundIn.ar(0);
		decay_time = MouseX.kr(0,16);
		delay_scale = MouseY.kr(0.01, 1);

		// 8 comb delays in parallel :
		sig = Mix.ar(CombL.ar(sig, 0.1, {0.04.rand2 + 0.05}.dup(8) * delay_scale,  decay_time));

		// chain of 5 allpass delays on each of two channels (10 total) :
		5.do({ sig = AllpassN.ar(sig, 0.050, {0.050.rand}.dup(4), 1) });

		sig = Pan2.ar(sig, Rand(-1,1));
		Out.ar(0, sig);
	}).send(s);

	SynthDef.new(\reverb2,{
		var sig, dt, ds, local;

		sig = SoundIn.ar(0);
		dt = MouseX.kr(0,1);
		ds = MouseY.kr(0.01, 1);

		4.do { sig = AllpassL.ar(sig, 0.03, {Rand(0.005,0.02)}.dup * ds, 1); };

		local = LocalIn.ar(2) * 0.98;
		local = OnePole.ar(local, dt);
		local = Rotate2.ar(local[0], local[1], 0.23);
		local = AllpassL.ar(local, 0.05, {Rand(0.01,0.05)}.dup * ds, 2);
		local = DelayL.ar(local, 0.3, [0.19,0.26] * ds);
		local = AllpassL.ar(local, 0.05, {Rand(0.03,0.15)}.dup * ds, 2);
		local = LeakDC.ar(local);
		local = local + sig;
		LocalOut.ar(local);

		Out.ar(0, local);
	}).send(s);


	// --------------------------------------------- Control ---------------------------------------------------

	// start controllers
	~aBus = nil;
	if(~wControllersAvail.isNil, {"Controllers.scd".loadRelative});

	OSCdef(\tsEx3d, {|msg|
		var cookie = msg[1];
		var val = msg[2];
		// cookie.postln;
		if( (cookie==6) && (val==1), {sauerEnabled = (sauerEnabled+1)%2});
		if( (cookie==7) && (val==1), {tenneyEnabled = (tenneyEnabled+1)%2});
		if(cookie==16, { // X
			if(sauerEnabled == 1, { { s2dSauer.activex = 1 - (val/1024) }.defer() });
			if(tenneyEnabled == 1, { { s2dTenney.activex = 1 - (val/1024) }.defer() });
		});
		if(cookie==17, { // Y
			if(sauerEnabled == 1, { { s2dSauer.activey = val/1024 }.defer() });
			if(tenneyEnabled == 1, { { s2dTenney.activey = val/1024 }.defer() });
		});
	},
	"/hid/ex3d"
	).fix;

OSCdef(\tsNoteOn, { |msg|
		var chan = msg[1], num = msg[2], val = msg[3], src = msg[4];
		(num/127).postln;
		if((notes[num].isNil) && (src==\LPK), {
			// notes[num] = Synth(\noise_ampmod, [\modfreqBus,cBus.modfreq,\filterfreqBus,cBus.filterfreq,\filterfreqBase, num/127]);
			notes[num] = Synth(\saw_ampmod, [\modfreqBus,cBus.modfreq,\filterfreqBus,cBus.filterfreq,\filterfreqBase, num/127]);
		});
		~midiOut.noteOn(1,num,127) ;
	},
	"/midi/noteOn"
	).fix;

	OSCdef(\tsNoteOff, { |msg|
		var chan = msg[1], num = msg[2], val = msg[3], src = msg[4];
		if((notes[num].notNil) && (src==\LPK), {
			notes[num].set(\gate,0);
			notes[num] = nil;
		});
		~midiOut.noteOff(1,num,127) ;
	},
	"/midi/noteOff"
	).fix;


	// --------------------------------------------- GUI ---------------------------------------------------

	wSauerTenney = Window("Sauer/Tenney hybrid organ", Rect(20,100,1000,800)).background_(Color.grey(0.99).alpha_(0.8));

	s2dSauerLabel = StaticText(wSauerTenney, Rect(100,20,300,50)).font_(Font("Courier",30)).string_("Sauer Control").align_(\center);
	s2dSauer = (Slider2D(wSauerTenney, Rect(20,100,470,470))
		.canFocus_(false).knobColor_(Color.black).x_(0.5).y_(0.5)
		.action_({
			var val = s2dSauer.x * 128;
			if( ~midiOutInit==1, {
				registerSelectNew = sauer.specRegSelect[ val ].asInt; // select register number index
				if(registerSelectNew != registerSelect, { // only if register number index changed
					registerSelect = registerSelectNew;
					if(sauer.deBug == 1, {("Register index" + registerSelect + "selected").postln});
					21.do({arg i;
						var regNbr = sauer.regList[i];
						if(registerSelect >=( i+1),
							{ // switch ON all registers lower or equal to registerSelect
								~midiOut.noteOn(sauer.chanRegNbr, regNbr, 127);
								if(sauer.deBug == 1, {("Register" + regNbr + "ON").postln});
							},
							{ // switch OFF all registers higher than regNbr
								~midiOut.noteOn(sauer.chanRegNbr, regNbr, 0);
								if(sauer.deBug == 1, {("Register" + regNbr + "OFF").postln});
						});
					});
				});
			});
		}) // action
	);

	s2dTenneyLabel = StaticText(wSauerTenney, Rect(610,20,300,50)).font_(Font("Courier",30)).string_("Tenney Control").align_(\center);
	s2dTenney = (Slider2D(wSauerTenney, Rect(510,100,470,470))
		.canFocus_(false).knobColor_(Color.black).x_(0.5).y_(0.5)
		.action_({ |slider|
			cBus.modfreq.set(slider.y);
			cBus.filterfreq.set(slider.x);
		})
	);

	wSauerTenney.onClose_({
		OSCdef.freeAll;
	});
	wSauerTenney.front;

}
)




