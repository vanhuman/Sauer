/*
playing notes on Sauer / Utopa to process and improvise with
following KP6-3.7
1. low pedal notes
2. Warp melody, different rhythms, same order of the notes
3. G notes, not too dense
4. add Warp melody samples
5. J massive sound, going into
6. K modulation
7. Glissandi, stop on climax

*/

(

var playnote, taskfunc;
var envs = Array.newClear(16);
var tasks = Array.newClear(16);
var taskKeys = [32, 33, 34, 35, 28, 29, 24, 25, 26, 27];
var taskLabels = [
	"--- A low notes ---", "--- B melody ---", "--- thrills on Bb-E ---", "--- thrills on D-F ---", "--- G ---", "--- J ---",
	"--- K low notes ---", "--- K melody ---", "--- K glissandi high ---", "--- K glissandi lower ---"
];

if (~bo.isNil) { "Utopa setup not loaded!".warn };

~midiOutDevice = "MUL";
MIDIIn.connectAll;
~mpk = MIDIout.new().getIDs()[3];

MIDIdef.cc(\organCC, {
	arg val, num, chan;
	var index = taskKeys.indexOf(num);
	// [chan, num, val].postln;
	if (index.notNil) {
		if (val > 0) {
			if (tasks[index].isNil) {
				tasks[index] = envs[index].use { Task(taskfunc) };
			};
			taskLabels[index].warn;
			tasks[index].play;
		} {
			tasks[index].stop;
		};
	};
}, srcID: ~mpk).fix;

playnote = {
	arg chans, notes, vel, dur = 0, delay = 0;
	if (~verbose) { format("Chan %, note %, duration % sec", chans, notes, dur.round(0.01)).postln };
	chans.size.do {|index|
		{ ~bo.midinote(chans[index], notes[index], vel) }.defer(delay);
		{ ~midiOut.noteOn(chans[index], notes[index], vel) }.defer(delay);
		if (dur > 0) {
			{ ~bo.midinote(chans[index], notes[index], 0) }.defer(dur + delay);
			{ ~midiOut.noteOn(chans[index], notes[index], 0) }.defer(dur + delay);
		};
	};
};

taskfunc = {
	var notes, midiNotes, wait, justRested = false, octaves, chord, nbr, noteIndex, count, chans;
	inf.do {
		if (~chans[0].isString) { ~chans = [~chans] };
		if (~notes[0].isString) { ~notes = [~notes] };
		if (~octaves[0].isInteger) { ~octaves = [~octaves] };
		if (~changed) {
			count = 0;
			~changed = false;
		};
		if ( (~chans.size == ~notes.size) && (~octaves.size == ~notes.size) ) {
			if (~skip.notNil and: { ~skip.coin }) {
				count = count + 1;
				if (~verbose) { "-- skip --".postln };
			};
			// --- note ----------------------------------
			nbr = ~notes[0].size;
			if (~random) {
				noteIndex = (0..nbr-1).choose;
			} {
				noteIndex = count%nbr;
			};
			chord = ~notes.size;
			notes = Array.new(chord);
			chord.do { |i|
				notes.add(~notes[i][noteIndex]);
			};
			if (~rest.notNil ) {
				if (~rest.coin and: { justRested.not } ) {
					notes = "rest";
					justRested = true;
				} {
					justRested = false;
				};
			};
			// --- octave ----------------------------------
			octaves = Array.new(chord);
			chord.do { |i|
				octaves.add(~octaves[i].choose);
			};
			// --- wait ----------------------------------
			if(~weight.isNil) {
				wait = rrand(~wait[0], ~wait[1]);
			} {
				wait = [~wait[0], ~wait[1]].wchoose(~weight);
			};
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
				~playnote.value(chans, midiNotes, 127, wait);
			} {
				if (~verbose) { "-- rest --".postln };
			};
			wait.wait;
		} {
			"Arrays for notes, chans and octaves do not match!".warn;
			1.wait;
		};
		count = count + 1;
	}
};

"--- A low notes ---".postln;
envs[0] = (
	notes: ["Bb", "E0"],
	chans: [0],
	octaves: [1, 2],
	rest: 0.1,
	skip: nil,
	wait: [6.0, 8],
	weight: nil,
	random: true,
	changed: true,
	verbose: false,
	playnote: playnote
);

"--- B melody ---".postln;
envs[1] = (
	notes: ["D0", "F0", "A0", "A0", "F0", "G0", "C0", "D0", "E0", "F0", "C0", "D0", "A0", "G0", "F0", "G0", "C0", "D0", "A0", "F0"],
	chans: [1],
	octaves: [4, 5, 6],
	rest: 0.2,
	skip: 0.1,
	wait: [0.4, 0.4] * 0.5,
	weight: [0.85, 0.15],
	random: false,
	changed: true,
	verbose: false,
	playnote: playnote
);

"--- thrills on Bb-E ---".postln;
envs[2] = (
	notes: ["Bb", "E0"],
	chans: [2],
	octaves: [5, 6, 7],
	rest: 0.2,
	skip: nil,
	wait: [0.01, 0.05],
	weight: nil,
	random: false,
	changed: true,
	verbose: false,
	playnote: playnote
);

"--- thrills on D-F ---".postln;
envs[3] = (
	notes: ["D0", "F0"],
	chans: [2],
	octaves: [5, 6, 7],
	rest: 0.2,
	skip: nil,
	wait: [0.01, 0.05],
	weight: nil,
	random: false,
	changed: true,
	verbose: false,
	playnote: playnote
);

"--- G ---".postln;
envs[4] = (
	notes: [
		["E0", "Bb", "E0", "Bb"],
		["E0", "F#", "C#", "B0v"]
	],
	chans: [1, 2],
	octaves: [ [2], [4] ],
	rest: nil,
	skip: 0.2,
	wait: [2, 2],
	weight: nil,
	random: false,
	changed: true,
	verbose: false,
	playnote: playnote
);

"--- J ---".postln;
envs[5] = (
	notes: [
		["E0", "E0", "E0", "E0"],
		["Bb", "Bb", "Bb", "Bb"],
		["E0", "Bb", "E0", "Bb"],
		["B0", "Bb", "A0", "E0^"]
	],
	chans: [0, 0, 1, 2],
	octaves: [ [1], [2], [3], [5] ],
	rest: nil,
	skip: nil,
	wait: [2, 2],
	weight: nil,
	random: false,
	changed: true,
	verbose: false,
	playnote: playnote
);

"--- K1 ---".postln;
envs[6] = (
	notes: [
		"C0"!9,
		"F#"!9,
	],
	chans: [0, 0],
	octaves: [ [2], [1, 2]],
	rest: nil,
	skip: nil,
	wait: [4, 6],
	weight: nil,
	random: false,
	changed: true,
	verbose: false,
	playnote: playnote
);

"--- K2 ---".postln;
envs[7] = (
	notes: [
		["B0", "C#", "B0", "Bb", "B0", "C#", "Eb", "D0", "C#"],
	],
	chans: [2],
	octaves: [ [4, 5] ],
	rest: nil,
	skip: nil,
	wait: [0.5, 0.5],
	weight: nil,
	random: false,
	changed: true,
	verbose: false,
	playnote: playnote
);

"--- K3 ---".postln;
envs[8] = (
	notes: [
		["C0", "C#", "D0", "D#", "E0", "F0", "F#", "G0", "G#", "A0", "A#", "B0"] ++
		["C0^", "C#^", "D0^", "D#^", "E0^", "F0^", "F#^", "G0^", "G#^", "A0^", "A#^", "B0^"] ++
		["B0^", "A#^", "A0^", "G#^", "G0^", "F#^", "F0^", "E0^", "D#^", "D0^", "C#^", "C0^"] ++
		["B0", "A#", "A0", "G#", "G0", "F#", "F0", "E0", "D#", "D0", "C#", "C0"]
	],
	chans: [0],
	octaves: [ [5]],
	rest: nil,
	skip: nil,
	wait: [0.01, 0.03],
	weight: nil,
	random: false,
	changed: true,
	verbose: false,
	playnote: playnote
);

"--- K4 ---".postln;
envs[9] = (
	notes: [
		["B0^", "A#^", "A0^", "G#^", "G0^", "F#^", "F0^", "E0^", "D#^", "D0^", "C#^", "C0^"] ++
		["B0", "A#", "A0", "G#", "G0", "F#", "F0", "E0", "D#", "D0", "C#", "C0"] ++
		["C0", "C#", "D0", "D#", "E0", "F0", "F#", "G0", "G#", "A0", "A#", "B0"] ++
		["C0^", "C#^", "D0^", "D#^", "E0^", "F0^", "F#^", "G0^", "G#^", "A0^", "A#^", "B0^"]
	],
	chans: [0],
	octaves: [ [4]],
	rest: nil,
	skip: nil,
	wait: [0.01, 0.03],
	weight: nil,
	random: false,
	changed: true,
	verbose: false,
	playnote: playnote
);

)




//////////////////////////////////////////////////////////////////////////

(

~organ = \sauer;
~midiOutDevice = "MUL";
MIDIout.new();

~play = EM();

~play.factor = 0.2;
~play.taskPlaying = 0;
~play.nbrOfTasks = 3;

if(~organ == \sauer, {
	~play.note = {
		arg evt, chan, note, vel, dur = 0, delay = 0;
		{ ~midiOut.noteOn(chan, note, vel) }.defer(delay);
		if (dur > 0) {
			{ ~midiOut.noteOn(chan, note, 0) }.defer(dur + delay);
		};
	};
});
if(~organ == \utopa, {
	~play.note = {
		arg evt, chan, note, vel, dur = 0, delay = 0;
		{ ~bo.midinote(chan, note, vel) }.defer(delay);
		if (dur > 0) {
			{ ~bo.midinote(chan, note, 0) }.defer(dur + delay);
		};
	};
});

~play.tasks = Array.newClear(~play.nbrOfTasks);

~play.tasks[0] = {
	arg evt;
	var note, dur;
	"Playing task 0".postln;
	inf.do {
		note = rrand(36, 48);
		dur = rrand(10, 15) * ~play.factor;
		~play.note(0, note, 127, dur);
		dur.wait;
		rrand(1, 2).wait;
	}
};

~play.tasks[1] = {
	arg evt;
	var notes = Array.newClear(2), dur;
	"Playing task 1".postln;
	inf.do {
		notes[0] = (36..48).choose;
		notes[1] = (36..48).takeThese({arg note; note == notes[0]}).choose;
		dur = rrand(5, 10) * ~play.factor;
		~play.note(0, notes[0], 127, dur);
		~play.note(0, notes[1], 127, dur, rrand(1, 2));
		dur.wait;
		rrand(2, 4).wait;
	}
};

~play.tasks[2] = {
	arg evt;
	var notes = Array.newClear(2), dur;
	"Playing task 2".postln;
	inf.do {
		notes[0] = (36..48).choose;
		notes[1] = (36..48).takeThese({arg note; note == notes[0]}).choose;
		20.do {
			dur = [0.01,0.05].choose;
			~play.note(0, notes[0], 127, dur);
			~play.note(0, notes[1], 127, dur);
			dur.wait;
			dur = [0.01,0.05].choose;
			~play.note(1, notes[0] + 12, 127, dur);
			~play.note(1, notes[1] + 12, 127, dur);
			dur.wait;
			dur = [0.01,0.05].choose;
			~play.note(2, notes[0], 127, dur);
			~play.note(2, notes[1], 127, dur);
			dur.wait;
		}
	}
};

~play.mainTask = {
	arg evt;
	var task, mainTask, taskPlaying = 100;
	mainTask = Task({
		inf.do {
			if (taskPlaying != evt.taskPlaying, {
				if (task.notNil) { task.stop };
				if (evt.taskPlaying < evt.tasks.size) {
					taskPlaying = evt.taskPlaying;
					task = Task(evt.tasks[evt.taskPlaying]);
					task.play;
				} {
					"Task generator stopped".postln;
					mainTask.stop;
				};
			});
			1.wait;
		};
	});
	mainTask
};

)

~task = ~play.mainTask;
~task.play;
~play.taskPlaying = 0;
~play.taskPlaying = 1;
~play.taskPlaying = 2;
~play.taskPlaying = 99;



