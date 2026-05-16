// Global audio system: three SFX one-shots + looping background music.
// All handles are static so sim systems can fire Audio::playX() without
// passing state around. Init/shutdown are called from main.mt and the
// SoundBuffers must outlive every Sound created from them (see Audio.mt
// in the SFML plugin for the lifetime contract).

import * from "@mtype-sfml/Audio.mt";

class Audio {
    public static SoundBuffer? bufChord = null;
    public static SoundBuffer? bufDing  = null;
    public static SoundBuffer? bufTada  = null;
    public static Sound?       sndChord = null;
    public static Sound?       sndDing  = null;
    public static Sound?       sndTada  = null;
    public static Music?       music    = null;
    public static int          inited   = 0;

    // Load SoundBuffers, create Sound instances, start looping music.
    // Call after __plugin_load of mtype-sfml.
    public static function init(): void {
        if (Audio::inited == 1) { return; }
        Listener::setGlobalVolume(80.0);

        Audio::bufChord = SoundBuffers::load("src/resources/audio/chord.wav");
        Audio::bufDing  = SoundBuffers::load("src/resources/audio/ding.wav");
        Audio::bufTada  = SoundBuffers::load("src/resources/audio/tada.wav");

        Audio::sndChord = Sounds::create(Audio::bufChord);
        Audio::sndChord.setVolume(60.0);
        Audio::sndDing  = Sounds::create(Audio::bufDing);
        Audio::sndDing.setVolume(45.0);
        Audio::sndTada  = Sounds::create(Audio::bufTada);
        Audio::sndTada.setVolume(70.0);

        Audio::music = MusicPlayer::open("src/resources/audio/music.mp3");
        Audio::music.setVolume(25.0);
        Audio::music.setLoop(true);
        Audio::music.play();

        Audio::inited = 1;
    }

    public static function shutdown(): void {
        if (Audio::inited == 0) { return; }
        if (Audio::music    != null) { Audio::music.stop();    Audio::music.destroy();    }
        if (Audio::sndChord != null) { Audio::sndChord.stop(); Audio::sndChord.destroy(); }
        if (Audio::sndDing  != null) { Audio::sndDing.stop();  Audio::sndDing.destroy();  }
        if (Audio::sndTada  != null) { Audio::sndTada.stop();  Audio::sndTada.destroy();  }
        if (Audio::bufChord != null) { Audio::bufChord.destroy(); }
        if (Audio::bufDing  != null) { Audio::bufDing.destroy();  }
        if (Audio::bufTada  != null) { Audio::bufTada.destroy();  }
        Audio::inited = 0;
    }

    public static function playChord(): void {
        if (Audio::sndChord != null) { Audio::sndChord.play(); }
    }
    public static function playDing(): void {
        if (Audio::sndDing != null) { Audio::sndDing.play(); }
    }
    public static function playTada(): void {
        if (Audio::sndTada != null) { Audio::sndTada.play(); }
    }
}
