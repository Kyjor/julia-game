module SoundSourceModule
    using ..JulGame
    import ..Component
    
    export SoundSource
    struct SoundSource
        channel::Int32
        isMusic::Bool
        path::String
        playOnStart::Bool
        volume::Int32
    end

    export InternalSoundSource
    mutable struct InternalSoundSource
        channel::Int32
        isMusic::Bool
        isPlaying::Bool
        parent::Any
        path::String
        playOnStart::Bool
        sound::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2._Mix_Music}, Ptr{SDL2.LibSDL2.Mix_Chunk}}
        volume::Int32

        # Music
        function InternalSoundSource(parent::Any, path::String, channel::Int32 = Int32(-1), volume::Int32 = Int32(-1), isMusic::Bool = false, playOnStart::Bool = false)
            this = new()

            SDL2.SDL_ClearError()
            fullPath = joinpath(BasePath, "assets", "sounds", path)
            if length(path) < 1
                sound = C_NULL    
            else
                sound = load_sound_sdl(path, isMusic)
            end
            error = unsafe_string(SDL2.SDL_GetError())

            if (sound == C_NULL || !isempty(error)) && length(path) > 0
                println(fullPath)
                error("Error loading file at $path. SDL Error: $(error)")
                SDL2.SDL_ClearError()
            end
            
            isMusic ? SDL2.Mix_VolumeMusic(Int32(volume)) : SDL2.Mix_Volume(Int32(channel), Int32(volume))

            this.channel = channel
            this.isMusic = isMusic
            this.parent = parent
            this.path = path
            this.sound = sound
            this.volume = volume
            this.isPlaying = false
            this.playOnStart = playOnStart

            return this
        end
    end

    function Component.toggle_sound(this::InternalSoundSource, loops = 0)
        if this.isMusic
            if SDL2.Mix_PlayingMusic() == 0
                SDL2.Mix_PlayMusic( this.sound, Int32(-1) )
            else
                if SDL2.Mix_PausedMusic() == 1 
                    SDL2.Mix_ResumeMusic()
                else
                    SDL2.Mix_PauseMusic()
                end
            end
        else
            SDL2.Mix_PlayChannel( Int32(this.channel), this.sound, Int32(loops) )
        end
    end
    
    function Component.stop_music(this::InternalSoundSource)
        SDL2.Mix_HaltMusic()
    end
    
    function Component.load_sound(this::InternalSoundSource, soundPath::String, isMusic::Bool)
        this.isMusic = isMusic
        SDL2.SDL_ClearError()
        this.sound = load_sound_sdl(soundPath, isMusic)
        error = unsafe_string(SDL2.SDL_GetError())
        if !isempty(error)
            println(string("Couldn't open sound! SDL Error: ", error))
            SDL2.SDL_ClearError()
            this.sound = C_NULL
            return
        end
        this.path = soundPath
    end

    function load_sound_sdl(soundPath::String, isMusic::Bool)
        if haskey(JulGame.AUDIO_CACHE, get_comma_separated_path(soundPath))
            raw_data = JulGame.AUDIO_CACHE[get_comma_separated_path(soundPath)]
            rw = SDL2.SDL_RWFromConstMem(pointer(raw_data), length(raw_data))
            if rw != C_NULL
                @debug("loading sound from cache")
                @debug("comma separated path: ", get_comma_separated_path(soundPath))
                return isMusic ? SDL2.Mix_LoadMUS_RW(rw, 1) : SDL2.Mix_LoadWAV_RW(rw, 1)
            end
        end
        @debug("loading sound from fs")

        fullPath = joinpath(BasePath, "assets", "sounds", soundPath)
        return isMusic ? SDL2.Mix_LoadMUS(fullPath) : SDL2.Mix_LoadWAV(fullPath)
    end

    function get_comma_separated_path(path::String)
        # Normalize the path to use forward slashes
        normalized_path = replace(path, '\\' => '/')
        
        # Split the path into components
        parts = split(normalized_path, '/')
        
        result = join(parts[1:end], ",")
    
        return result  
    end

    function Component.unload_sound(this::InternalSoundSource)
        if this.isMusic
            SDL2.Mix_FreeMusic(this.sound)
        else
            SDL2.Mix_FreeChunk(this.sound)
        end
        this.sound = C_NULL
    end
end
