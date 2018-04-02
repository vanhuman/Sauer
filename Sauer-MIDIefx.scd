// processing note input from Sauer via EXT input (MIDISport f.e.)
// more interesting effects
// incorporate note length

(
var task, fEcho, fChord, fRandom, fThrill, currentNote;
var notes = Array.newClear(127), tasks = Array.newClear(127), conditions = Condition.new.dup(127);
var outChan = 3, inChan = 1;

var effects = [\echo, \chord, \random, \thrill];
~effectNbr = 0; // echo
~effectNbr = 1; // chord
~effectNbr = 2; // random
~effectNbr = 3; // thrill

// start controllers
~midiOutInit = 1;
~midiInDevice = \EXT;
~midiOutDevice = "MUL";
// ~midiOutDevice = "IAC1";
if(~wControllersAvail.isNil, { (Document.dir++"Lapis/Controllers.scd").load });

fThrill = {
	var note = currentNote;
	inf.do {
		~midiOut.noteOn(2,note,127);
		[0.01,0.05].choose.wait;
		~midiOut.noteOn(2,note,0);
		~midiOut.noteOn(3,note+12,127);
		[0.01,0.05].choose.wait;
		~midiOut.noteOn(3,note+12,0);
		conditions[note].wait;
	};
};

fChord = {
	var note = currentNote;
	1.do {
		~midiOut.noteOn(outChan,note+7,127);
		~midiOut.noteOn(outChan,note+9,127);
		~midiOut.noteOn(outChan,note+12,127);
		conditions[note].wait;
		~midiOut.noteOn(outChan,note+7,0);
		~midiOut.noteOn(outChan,note+9,0);
		~midiOut.noteOn(outChan,note+12,0);
	};
};

fEcho = {
	var note = currentNote;
	var step = 1, max = [120, note+10].wchoose([0.1,0.9]);
	inf.do { |i|
		step = i%(max-note);
		[note,step].postln;
		~midiOut.noteOn(outChan,note+step,127);
		[0.05,0.2].wchoose([0.9,0.1]).wait;
		~midiOut.noteOn(outChan,note+step,0);
		conditions[note].wait;
	};
};

fRandom = {
	var note = currentNote, temp;
	inf.do { |j|
		i = j%3;
		rrand(0.01,0.02).wait;
		temp = (12*i)+note+rrand(0,4);
		~midiOut.noteOn(outChan,temp,127);
		rrand(0.02,0.03).wait;
		~midiOut.noteOn(outChan,temp,0);
		temp = (12*i)+note+rrand(0,8);
		~midiOut.noteOn(outChan,temp,127);
		rrand(0.03,0.04).wait;
		~midiOut.noteOn(outChan,temp,0);
		temp = (12*i)+note+rrand(0,12);
		~midiOut.noteOn(outChan,temp,127);
		rrand(0.02,0.05).wait;
		~midiOut.noteOn(outChan,temp,0);
		temp = (12*i)+note+rrand(0,24);
		~midiOut.noteOn(outChan,temp,127);
		rrand(0.03,0.05).wait;
		~midiOut.noteOn(outChan,temp,0);
		temp = (12*i)+note+rrand(0,24);
		~midiOut.noteOn(outChan,temp,127);
		rrand(0.03,0.05).wait;
		~midiOut.noteOn(outChan,temp,0);
		conditions[note].wait;
	};
};

OSCdef(\sauerNoteOn, {  |msg|
	var chan, note, vel, src;
	chan = msg[1];
	note = msg[2];
	vel = msg[3];
	src = msg[4];
	["NON", chan,note,vel,src].postln;

	if( (chan==inChan) && (src==~midiInDevice), {

		currentNote = note;
		notes[note] = 127;
		tasks[note].stop;

		case
		{effects[~effectNbr] == \thrill}
		{
			conditions[note].test = true; conditions[note].signal;
			tasks[note] = Task(fThrill).start;
		}
		{effects[~effectNbr] == \chord}
		{
		conditions[note].test = false; conditions[note].signal;
		tasks[note] = Task(fChord).start;
		}
		{effects[~effectNbr] == \echo}
		{
			conditions[note].test = true; conditions[note].signal;
			tasks[note] = Task(fEcho).start;
		}
		{effects[~effectNbr] == \random}
		{
			conditions[note].test = true; conditions[note].signal;
			tasks[note] = Task(fRandom).start;
		}
		;

		// tasks[note] = Task(fRandom).start;

	});

},
"/midi/noteOn"
).fix;

OSCdef(\sauerNoteOff, {  |msg|
	var chan, note, vel, src;
	chan = msg[1];
	note = msg[2];
	vel = msg[3];
	src = msg[4];
	["NOF", chan,note,vel,src].postln;

	if( (chan==inChan) && (src==~midiInDevice), {
		notes[note] = 0;
		case
		{effects[~effectNbr] == \thrill}
		{
			conditions[note].test = false; conditions[note].signal;
		}
		{effects[~effectNbr] == \chord}
		{
			conditions[note].test = true; conditions[note].signal;
		}
		{effects[~effectNbr] == \echo}
		{
			conditions[note].test = false; conditions[note].signal;
		}
		{effects[~effectNbr] == \random}
		{
			conditions[note].test = false; conditions[note].signal;
		}
		;
	});

},
"/midi/noteOff"
).fix;


)



~localAddr = NetAddr("127.0.0.1", 57120);
~localAddr.sendMsg("/midi/noteOn", 1, 40, 1, "EXT")
~localAddr.sendMsg("/midi/noteOff", 1, 40, 1, "EXT")

~localAddr.sendMsg("/midi/noteOn", 1, 70, 1, \EXT)
~localAddr.sendMsg("/midi/noteOff", 1, 70, 1, \EXT)


