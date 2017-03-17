// SauerControl: to organize control from and to the Sauer Organ
// to use with the ShackleSystem and SynthKeys
// when using without Shackle System, first start SynthKeys & InOut and then this program

// if midiSend is enabled (from the ShackleSystem of by setting it below):
// 		register changes and assignments will be sent to Sauer
//		the joystick will send notes to Sauer
//		the joystick buttons 1 & 2 will be disabled in LiveSampler
//  	LPK keyboard will send notes to Sauer
// if midiReceive is enabled (from the ShackleSystem of by setting it below):
// 		SynthKeys will receive MIDI notes from external source (specified in SynthKeys) and disable the joystick X
//		midi received from the external source (specified below) will be converted to HID and send to SynthKeys to fake joystick data (only X)

(

//////////////// variables ////////////////////////////////

var cfg = (
	version: "0.9",
	midiReceiveEnabled: 1, // receive midi from Sauer
	midiSrc: \EXT, // MIDI src the external MIDI is received from
	midiPchan: 2, // external channel for pitch - Sauer organ chan 2 (0-15) - MIDI kb chan 3
	midiPnum: 1, // external controller number for pitch - Sauer organ ctr 1 - MIDI kb ctr 1
	midiDchan: 12, // external channel for distortion - Sauer organ chan 12 (0-15) - MIDI kb chan 3
	midiDnum: 1, // external controller number for distortion - Sauer organ ctr 1 - MIDI kb ctr 6
	midiSendEnabled: 1, // send midi to Sauer
	joystickTriggerEnabled: 1, // disable triggering notes thru task with the joystick trigger button
	docDir: Document.dir,
	dataDir: "Sauer/Data/",
	dummy: 0
);

var screenHeight = Window.screenBounds.height, screenWidth = Window.screenBounds.width;
var respMidiReceive, respCTR, bMidiReceiveStatus, respHidEx3d, respPanic, respMidiSend, bMidiSendStatus, bMidiOutInfo, bPlayEDNAH;
var signalColor = Color.yellow(0.9);
var localAddr = NetAddr("127.0.0.1", 57120);

var sauer = (
	noteChord: [5,0,2,7], // [0,1,11,19], // [0,5,7,8,10,8,7,5,7], //[0,1,2,1]
	specRepVal: Env.new([0.1,1,2],[0.5,0.5],[\lin]), // repetiton range
	specNoteLen: Env.new([0.1,5],[1.0],[\lin]), // note length range
	specNoteNbr: Env.new([36,81],[127],[\lin]), // note nbr range
	// specNoteNbr: Env.new([24,36,48,60,72],[32,32,32,32],[\step]), // note nbr range
	chanEx3dPro: 1, // MIDI channel for notes
//	assignmentList: [68,70,72,75], // list of MIDI notes that switch on assignments to manual II on channel 2 (0-15)
//	assignmentList: [67,68,69,70,71,72,73,74,75,76], // manual II with ^ and V
//	assignmentList: [52,54,56,59], // for manual I on channel 1 (0-15)
	assignmentList: [51,52,53,54,55,56,57,58,59,60], // manual I with ^ and V
	chanRegNbr: 13, // MIDI channel for registration and assignment selection
	// specRegSelect: Env.new([1,2,20,20.9],[6,116,6],[\lin]),
	// regList: [14,20,13,12,19,18,11,10,17,16,9,8,7,3,6,5,4,2,1,0,15],
	specRegSelect: Env.new([1,2,10,10.9],[6,116,6],[\lin]),
	regList: [14,20,13,12,19,18,11,10,17,16,9],
		// list of registrations to switch on/off, should be array of 21 of which the last one is never ON
	resetNote: 101,
	notes: Array.newClear(127),
	deBug: 1
	);
var noteNbr = 60, repVal = 1, noteLen = 1, noteChangeEnabled = 0, registerSelect = 1;
var noteArray = Array.newClear(128), tEx3dProRunning = 0, tEx3dPro, registerSelectNew, fEx3dPro, fHandleNote, fStopNotes;
var specPitch = Env.new([0.5,0.5],[1],[\lin]); // map MIDI from Sauer for pitch control SK prog4
var ednahMidiFile, ednahMidiPlayer, ednahAudioPlayer;

var controllersFile = cfg.docDir++"Lapis/Controllers.scd";

// start controllers
if(~wControllersAvail.isNil, {controllersFile.load});
a = DiskPlayer.new(s); // load SynthDefs

//////////////// functions ////////////////////////////////

fHandleNote = { // this function deals with note on/off - as vars are local this will make sure there are no hanging notes
	arg nbr, len;
	nbr = nbr.asInt;
	("Triggering MIDI note" + nbr).postln;
	~midiOut.noteOn(sauer.chanEx3dPro,nbr,127);
	{~midiOut.noteOff(sauer.chanEx3dPro,nbr,127); }.defer(len);
};

fEx3dPro = { // this function will be run as a task on trigger, and repeatedly sends out MIDI notes
	var count = 0;
	if(cfg.joystickTriggerEnabled == 1, {
		inf.do({
			fHandleNote.value(noteNbr + sauer.noteChord[count],min(repVal,noteLen));
			(repVal + 0.01).wait;
			count = count + 1; if(count == sauer.noteChord.size, {count = 0});
		});
	});
};

fStopNotes = {
	sauer.notes.size.do { |nbr|
		if(sauer.notes[nbr].notNil, { ~midiOut.noteOff(sauer.chanEx3dPro,nbr,127); sauer.notes[nbr] = nil; ("Stopped note"+nbr).postln;});
	};
};

//////////////// responders ////////////////////////////////

// catch message midi send is enabled
respMidiSend = OSCresponderNode(nil, "/midiSendEnable", {
	arg time, responder, msg;
	cfg.midiSendEnabled = msg[1];
	{bMidiSendStatus.background_(if(msg[1]==1,{signalColor},{Color.white}))}.defer();
	if(msg[1] == 0, {
		// stop MIDI note task
		tEx3dPro.stop;
		tEx3dProRunning = 0;
		// stop all notes that are running
		fStopNotes.value;
		// reset organ to 0
		~midiOut.noteOn(sauer.chanRegNbr,sauer.resetNote,127);
		// enable buttons on joystick
		localAddr.sendMsg("/button1disable", 0);
		localAddr.sendMsg("/button2disable", 0);
	},
	{
		// reset organ to 0
		~midiOut.noteOn(sauer.chanRegNbr,sauer.resetNote,127);
		// switch on the necessary assignments
		sauer.assignmentList.size.do({|i|
			~midiOut.noteOn(sauer.chanRegNbr, sauer.assignmentList[i], 127);
		});
		// disable buttons on joystick
		localAddr.sendMsg("/button1disable", 1);
		localAddr.sendMsg("/button2disable", 1);
	});
}).add;

// send MIDI out from Extreme 3D pro
respHidEx3d = OSCresponderNode(nil, "/hid/ex3d",{ arg time, responder, msg;
	var cookie = msg[1];
	var val = msg[2];
	// ("SauerControl OSC RCV Ex3d: " ++ msg).postln;

	if(cfg.midiSendEnabled == 1, {
		if(cookie == 16, { // X-axis
			if(noteChangeEnabled == 1, {noteNbr = sauer.specNoteNbr.at(((1024 - val)/1024)*127)})
			});
		if((cookie == 17) && (tEx3dProRunning == 1), { // Y-axis
			val = val / 8; // map resolution 1024 to 128
			registerSelectNew = sauer.specRegSelect[val].asInt; // select register number index
			if(registerSelectNew != registerSelect, { // only if register number index changed
				registerSelect = registerSelectNew;
				if(sauer.deBug == 1, {("Register index" + registerSelect + "selected").postln});
				sauer.regList.size.do({arg i;
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
		if(cookie == 19, // Rotation
			 {repVal = sauer.specRepVal.at(1 - (val/255))});
		if(cookie == 20, // Slider
			 {noteLen = sauer.specNoteLen.at(1 - (val/255))});
		if(cookie == 4, { // trigger button
			case
			{val == 0} {tEx3dPro = Task(fEx3dPro).play; tEx3dProRunning = 1;}
			{val == 1} {tEx3dPro.stop; tEx3dProRunning = 0; if(cfg.joystickTriggerEnabled == 1, {fStopNotes.value})}
			;
		});
		if(cookie == 5, { // button 2, enable/disable changing note with X-Axis
			noteChangeEnabled = 1 - val;
			});

		});
	}).add;

// send MIDI notes from any channel of LPK to specific Sauer channel
OSCdef(\sauerNON, { |msg|
	var chan, note, vel, src;
	chan = msg[1];
	note = msg[2];
	vel = msg[3];
	src = msg[4];
	//	[chan,note,vel,src].postln;
	if( (cfg.midiSendEnabled == 1) && ( src==\LPK ), {
		~midiOut.noteOn(sauer.chanEx3dPro,note,127);
		sauer.notes[note] = 127;
	});
	if( (src==\MUL) && (note==95), { bPlayEDNAH.valueAction_(1) }); // MIDI file start
	},
"/midi/noteOn"
).fix;
OSCdef(\sauerNOF, { |msg|
	var chan, note, vel, src;
	chan = msg[1];
	note = msg[2];
	vel = msg[3];
	src = msg[4];
	//	[chan,note,vel,src].postln;
	if( (cfg.midiSendEnabled == 1) && ( src==\LPK ), {
		~midiOut.noteOff(sauer.chanEx3dPro,note,127);
		sauer.notes[note] = nil;
	});
	if( (src==\MUL) && (note==95), { bPlayEDNAH.valueAction_(0) }); // MIDI file stop
},
"/midi/noteOff"
).fix;

// catch message midi receive is enabled
respMidiReceive = OSCresponderNode(nil, "/midiReceiveEnable", {
	arg time, responder, msg;
//	("SauerControl: extMidi is" + if(msg[1] == 1, "ON", "OFF")).postln;
	cfg.midiReceiveEnabled = msg[1];
	{bMidiReceiveStatus.background_(if(msg[1]==1,{signalColor},{Color.white}))}.defer();

	// reset vars in SynthKeys
	if(msg[1]==1, {
		localAddr.sendMsg("/hid/ex3d", 16, 0.5 * 1024, 1);
		localAddr.sendMsg("/hid/ex3d", 17, 0.5 * 1024, 1);
		localAddr.sendMsg("/hid/ex3d", 19, 0.5 * 256, 1);
		localAddr.sendMsg("/hid/ex3d", 20, 1 * 256, 1);
		});
	}).add;

// convert MIDI control to HID to send to SynthKeys
respCTR = OSCresponderNode(nil, "/midi/control", { arg time, responder, msg;
	var chan, num, val, src;
	chan = msg[1];
	num = msg[2];
	val = msg[3];
	src = msg[4];
	// [src, chan,num,val].postln;
//	cfg.midiReceiveEnabled.postln;

	if((cfg.midiReceiveEnabled == 1) && (src == cfg.midiSrc), {
		case
		{(chan == cfg.midiPchan) && (num == cfg.midiPnum)}
			{// cookie 17/16 for Y/X axes, value in the range 0-1024, fromMidi=1
			// localAddr.sendMsg("/hid/ex3d", 17, specPitch.at(val) * 1024, 1);
			localAddr.sendMsg("/hid/ex3d", 16, 1024 - (val * 1024), 1);
			}
		{(chan == cfg.midiDchan) && (num == cfg.midiDnum)}
			// cookie 19 for Rotation, value in the range 0-256, 1: fromMidi
		// {localAddr.sendMsg("/hid/ex3d", 19, val * 256, 1)} // control length
		// {localAddr.sendMsg("/hid/ex3d", 20, val * 256, 1)} // control distortion
			; // case
		});

	}).add;

// responder to stop notes on Sauerorgan
respPanic = OSCresponderNode(nil, "/panic", {
	arg time, responder, msg;
		if(cfg.midiSendEnabled == 1, {
			"Panic Sauer".postln;
			// reset organ to 0
			~midiOut.noteOn(sauer.chanRegNbr,sauer.resetNote,127);
			// switch on the necessary assignments
			sauer.assignmentList.size.do({|i|
				~midiOut.noteOn(sauer.chanRegNbr, sauer.assignmentList[i], 127);
				});
		});
	}).add;


//////////////// GUI ////////////////////////////////

~wSauerControl = Window("SauerControl | Sunday Rhino | v" ++ cfg.version, Rect((screenWidth - 625), (screenHeight - 460), 350, 140))
	.background_(Color.grey(1));
~wSauerControlAvail = 1;

bMidiReceiveStatus = (SmoothButton(~wSauerControl, Rect(30,15,140,25)).border_(1).radius_(2)
	.states_([["MIDI Receive"]])
	.font_(Font("Helvetica-Bold",18))
	.canFocus_(false)
	.background_(Color.white)
);

bMidiSendStatus = (SmoothButton(~wSauerControl, Rect(30,50,140,25)).border_(1).radius_(2)
	.states_([["MIDI Send"]])
	.font_(Font("Helvetica-Bold",18))
	.canFocus_(false)
	.background_(Color.white)
);

bMidiOutInfo = (SmoothButton(~wSauerControl, Rect(30,100,290,20)).border_(1).radius_(2)
	.canFocus_(false)
	.states_([[
	"MIDI out" + if(~midiOutInit==1, {"ENABLED"},{"DISABLED"}) +
		" |  MIDI out device:" + ~midiOutDevice]])
	.font_(Font("Helvetica",12))
	.background_(if(~midiOutInit==1, {signalColor},{Color.red}))
);

bPlayEDNAH = (SmoothButton(~wSauerControl, Rect(180,15,140,25)).border_(1).radius_(2)
	.states_([ ["Play EDNAH"],  ["Stop EDNAH", Color.white, Color.red ] ])
	.font_(Font("Helvetica-Bold",18))
	.canFocus_(false)
	.background_(Color.white)
	.action_({
		if(bPlayEDNAH.value==1, {
			// ednahAudioPlayer = DiskPlayer.new(s,
			// 	"/Users/Robert/---data---/Audio/projecten-a/Sunday Rhino/Audio/In deine Hände retrogade sculpture -lastbar.wav",
			// 	// "/Users/Robert/---data---/Audio/projecten-a/Sunday Rhino/Audio/In deine Hände-reverse.wav", lev: 0.5,
			// 	out: 0, rel: 3
			// );
			// ednahAudioPlayer.start;
			ednahMidiFile = SimpleMIDIFile.read(
				cfg.docDir ++ cfg.dataDir ++ "/SundayRhino/In deine Hände Sauer retrogade Bes decimate.mid");
			{ ednahMidiPlayer = (ednahMidiFile.p(amp:1,useTrackChan: false) <> (type: \midi, midiout: ~midiOut, chan: 1)).play }.defer(0.1);
		},
		{
			// ednahAudioPlayer.stop;
			ednahMidiPlayer.stop;
		})
	})
);

~wSauerControl.onClose_({
	~wSauerControlAvail = nil;
	respMidiReceive.remove;
	respCTR.remove;
	respHidEx3d.remove;
	respPanic.remove;
	respMidiSend.remove;
	OSCdef(\sauerNON).free; OSCdef(\sauerNOF).free;
	});

localAddr.sendMsg("/midiSendEnable", cfg.midiSendEnabled);
localAddr.sendMsg("/midiReceiveEnable", cfg.midiReceiveEnabled);

~wSauerControl.front;

)
