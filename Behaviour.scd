/* playing notes on Sauer / Utopa to process and improvise with */

// Lapis
(
~lisa = "LiveSampler.scd";
~sk = "SynthKeysMPKorgans.scd";
"../Lapis/InOut.scd".loadRelative();
)

(
// ------------ Baroque Organ Setup ------------
if(~bo.notNil, { ~bo.clearAll() });
~bo = EM(); // functions in an EM always have the environment as first argument
~bo.addr = NetAddrMon.new("192.168.0.1", 1803);
// ~bo.addr = NetAddrMon.new("127.0.0.1", 8000);

~bo.noteOffset = 0;
~bo.chanOffset = 0;
~bo.upperRange = 85; // not sounding from 86 - 92
(Document.dir ++ "KP6-3.7/Lib/Definitions.scd").load();
(Document.dir ++ "KP6-3.7/Lib/Gui.scd").load();
)

// ------------ MIDI Setup ------------
(
var playnote, taskfunc, fStopAllNotes;
// bank A: 20 - 27 / bank B: 28 - 35
var taskKeys = [24, 25, 26, 27, 28, 29, 30, 31, 20, 21];
var taskLabels = [
	"--- A low notes ---", "--- B melody ---", "--- thrills on Bb-E ---", "--- thrills on D-F ---", "--- G ---", "--- J ---",
	"--- K low notes ---", "--- K melody ---", "--- K glissandi high ---", "--- K glissandi lower ---"
];
var envs = Array.newClear(taskKeys.size);
var tasks = Array.newClear(taskKeys.size);
var tasksRunning = false!(taskKeys.size);
var verbose = false, fStartTask;

if (~bo.isNil) { "Utopa setup not loaded!".warn };

~midiOutDevice = "MUL";
// ~midiOutDevice = "EXT";
~mpk = SetMIDIOut.new().getIDs()[3];

fStartTask = {
	arg index, val;
	if (val > 0) {
		if (tasks[index].isNil) { tasks[index] = envs[index].use { Task(taskfunc) } };
		("Started: " + taskLabels[index]).warn;
		envs[index].restart = true;
		tasks[index].play;
		tasksRunning[index] = true;
	} {
		("Stopped: " + taskLabels[index]).warn;
		tasks[index].stop;
		tasksRunning[index] = false;
	};
};

fStopAllNotes = {
	"Stop all notes".postln;
	4.do { |index|
		127.do { |note|
			~midiOut.noteOff(index, note, 127);
		}
	}
};

MIDIdef.cc(\organCCenvs, {
	arg val, num, chan;
	var index = taskKeys.indexOf(num);
	// [chan, num, val].postln;
	if (index.notNil) {
		fStartTask.value(index, val);
	};
}, ccNum: taskKeys, srcID: ~mpk);

MIDIdef.cc(\organCCcontrol4, {
	arg val, num, chan;
	var glissandiSpeed = 1;
	// [chan, num, val].postln;
	glissandiSpeed = val.linexp(0, 127, 0.5, 10);
	envs[8].speed = glissandiSpeed;
	envs[9].speed = glissandiSpeed;
}, ccNum: 4, srcID: ~mpk);

MIDIdef.cc(\organCCcontrol5, {
	arg val, num, chan;
	var glissandiDirectionRandom = 0;
	// [chan, num, val].postln;
	glissandiDirectionRandom = val.linlin(0, 127, 0.0, 0.9);
	envs[8].direction = glissandiDirectionRandom;
	envs[9].direction = glissandiDirectionRandom;
}, ccNum: 5, srcID: ~mpk);

playnote = {
	arg chans, notes, vel, dur = 0, delay = 0;
	if (~verbose) { format("Chan %, note %, duration % sec", chans, notes, dur.round(0.01)).postln };
	chans.size.do {|index|
		// { ~bo.midinote(chans[index], notes[index], vel) }.defer(delay);
		{ ~midiOut.noteOn(chans[index], notes[index], vel) }.defer(delay);
		if (dur > 0) {
			// { ~bo.midinote(chans[index], notes[index], 0) }.defer(dur + delay);
			{ ~midiOut.noteOn(chans[index], notes[index], 0) }.defer(dur + delay);
		};
	};
};

taskfunc = {
	var notes, midiNotes, wait, justRested = false, octaves, chord, nbr, noteIndex, count, chans, dur, sign = 1;
	inf.do {
		if (~chans[0].isString) { ~chans = [~chans] };
		if (~notes[0].isString) { ~notes = [~notes] };
		if (~octaves[0].isInteger) { ~octaves = [~octaves] };
		if (~restart) { count = 0; ~restart = false };
		if ( (~chans.size == ~notes.size) && (~octaves.size == ~notes.size) ) {
			if (~skip.notNil and: { ~skip.coin }) { count = count + 1; if (~verbose) { "-- skip --".postln } };
			// --- note ----------------------------------
			nbr = ~notes[0].size;
			if (~random) { noteIndex = (0..nbr-1).choose } { noteIndex = count%nbr };
			chord = ~notes.size;
			notes = Array.new(chord);
			chord.do { |i| notes.add(~notes[i][noteIndex]) };
			if (~rest.notNil ) {
				if (~rest.coin and: { justRested.not } ) { notes = "rest"; justRested = true } { justRested = false };
			};
			// --- octave ----------------------------------
			octaves = Array.new(chord);
			chord.do { |i| octaves.add(~octaves[i].choose) };
			// --- wait ----------------------------------
			if(~weight.isNil) {
				wait = rrand(~wait[0], ~wait[1]);
			} {
				wait = [~wait[0], ~wait[1]].wchoose(~weight);
			};
			dur = wait;
			if (~speed.notNil and: { ~speed > 1 }) { dur = wait * ~speed / 2 };
			if (~durationFactor.notNil) { dur = wait * rrand(1, 1 - ~durationFactor) };
			// --- play -------------------------------------
			if(notes != "rest") {
				midiNotes = Array.new(chord);
				chans = Array.new(chord);
				if (~verbose) { ("Chord:" + notes).postln };
				notes.do { |note, index|
					var add = 0;
					if (note[note.size-1] == $v) { add = -1; note = note.subStr(0, note.size - 2); };
					if (note[note.size-1] == $^) { add = 1; note = note.subStr(0, note.size - 2); };
					midiNotes.add(note.notemidi + (12 * (octaves[index] + add)));
					chans.add(~chans[index]);
				};
				~playnote.value(chans, midiNotes, 127, dur);
			} {
				if (~verbose) { "-- rest --".postln };
			};
			if (~speed.notNil) { wait = wait * ~speed };
			wait.wait;
		} {
			"Arrays for notes, chans and octaves do not match!".warn;
			1.wait;
		};
		if (sign == 1) { if (~direction.coin) { sign = -1 } } { if (~direction.coin) { sign = 1 } };
		count = count + sign;
	}
};

"--- A low notes ---".postln;
envs[0] = (
	notes: ["Bb", "C1", "E0"], chans: [0], octaves: [2],
	rest: nil, skip: nil, random: false,
	wait: [6.0, 6], weight: nil, durationFactor: 0.1,
	restart: true, verbose: verbose, playnote: playnote, direction: 0
);

"--- B melody ---".postln;
envs[1] = (
	notes: ["D0", "F0", "A0", "A0", "F0", "G0", "C0", "D0", "E0", "F0", "C0", "D0", "A0", "G0", "F0", "G0", "C0", "D0", "A0", "F0"],
	chans: [1], octaves: [4, 5, 6],
	rest: 0.2, skip: 0.1, random: true,
	wait: [0.4, 0.8] * 0.5, weight: [0.85, 0.15], durationFactor: 0.2,
	restart: true, verbose: verbose, playnote: playnote, direction: 0
);

"--- thrills on Bb-E ---".postln;
envs[2] = (
	notes: ["Bb", "E0"], chans: [2], octaves: [5, 6, 7],
	rest: 0.2, skip: nil, random: false,
	wait: [0.01, 0.05], weight: nil, durationFactor: nil,
	restart: true, verbose: verbose, playnote: playnote, direction: 0
);

"--- thrills on D-F ---".postln;
envs[3] = (
	notes: ["D0", "F0"], chans: [2], octaves: [5, 6, 7],
	rest: 0.2, skip: nil, random: false,
	wait: [0.01, 0.05], weight: nil, durationFactor: nil,
	restart: true, verbose: verbose, playnote: playnote, direction: 0
);

"--- G ---".postln;
envs[4] = (
	notes: [
		["E0", "Bb", "E0", "Bb"],
		["E0", "F#", "C#", "B0v"]
	],
	chans: [1, 2], octaves: [ [2], [4] ],
	rest: nil, skip: 0.2, random: false,
	wait: [2, 2], weight: nil, durationFactor: nil,
	restart: true, verbose: verbose, playnote: playnote, direction: 0
);

"--- J ---".postln;
envs[5] = (
	notes: [
		["E0", "E0", "E0", "E0"],
		["Bb", "Bb", "Bb", "Bb"],
		["E0", "Bb", "E0", "Bb"],
		["B0", "Bb", "A0", "E0^"]
	],
	chans: [0, 0, 1, 2], octaves: [ [2], [2], [3], [5] ],
	rest: nil, skip: nil, random: false,
	wait: [2, 2], weight: nil, durationFactor: 0.05,
	restart: true, verbose: verbose, playnote: playnote, direction: 0
);

"--- K1 ---".postln;
envs[6] = (
	notes: [
		"C0"!9,
		"F#"!9,
	],
	chans: [0, 0], octaves: [ [2], [2]],
	rest: nil, skip: nil, random: false,
	wait: [4, 6], weight: nil, durationFactor: 0.05,
	restart: true, verbose: verbose, playnote: playnote, direction: 0
);

"--- K2 ---".postln;
envs[7] = (
	notes: [
		["B0", "C#", "B0", "Bb", "B0", "C#", "Eb", "D0", "C#"],
	],
	chans: [1], octaves: [ [4, 5] ],
	rest: nil, skip: nil, random: false,
	wait: [0.5, 0.5], weight: nil, durationFactor: nil,
	restart: true, verbose: verbose, playnote: playnote, direction: 0
);

"--- K3 ---".postln;
envs[8] = (
	notes: [
		["C0", "C#", "D0", "D#", "E0", "F0", "F#", "G0", "G#", "A0", "A#", "B0"] ++
		["C0^", "C#^", "D0^", "D#^", "E0^", "F0^", "F#^", "G0^", "G#^", "A0^", "A#^", "B0^"] ++
		["B0^", "A#^", "A0^", "G#^", "G0^", "F#^", "F0^", "E0^", "D#^", "D0^", "C#^", "C0^"] ++
		["B0", "A#", "A0", "G#", "G0", "F#", "F0", "E0", "D#", "D0", "C#", "C0"]
	],
	chans: [2], octaves: [ [5] ],
	rest: nil, skip: nil, random: false,
	wait: [0.01, 0.03], weight: nil, durationFactor: nil, speed: 1,
	restart: true,	verbose: verbose, playnote: playnote, direction: 0
);

"--- K4 ---".postln;
envs[9] = (
	notes: [
		["B0^", "A#^", "A0^", "G#^", "G0^", "F#^", "F0^", "E0^", "D#^", "D0^", "C#^", "C0^"] ++
		["B0", "A#", "A0", "G#", "G0", "F#", "F0", "E0", "D#", "D0", "C#", "C0"] ++
		["C0", "C#", "D0", "D#", "E0", "F0", "F#", "G0", "G#", "A0", "A#", "B0"] ++
		["C0^", "C#^", "D0^", "D#^", "E0^", "F0^", "F#^", "G0^", "G#^", "A0^", "A#^", "B0^"]
	],
	chans: [3], octaves: [ [4] ],
	rest: nil, skip: 0.1, random: false,
	wait: [0.01, 0.04], weight: nil, durationFactor: nil, speed: 1,
	restart: true, verbose: verbose, playnote: playnote, direction: 0
);

w = Window("Sauer Notes", Rect(650, 60, 200, 40)).background_(Color.rand);
StaticText(w, Rect(20, 10, 160, 20)).string_("SAUER NOTES").align_(\center);

w.view.keyDownAction_({
	arg view, char, modifiers, unicode, keycode;
	var numberKeys = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29], index;

	if(keycode === 53, {
		fStopAllNotes.value();
	});

	// Number keys select patterns
	index = numberKeys.indexOf(keycode);
	if(index.notNil, {
		if (tasksRunning[index].not,
			{ fStartTask.value(index, 127) },
			{ fStartTask.value(index, 0) });
	})
});

w.onClose = {
	MIDIdef.freeAll;
	tasks.do { |task|
		task.stop;
	};
};
w.alwaysOnTop = true;
w.front;
)



