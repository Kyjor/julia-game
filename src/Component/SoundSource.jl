module SoundSourceModule
    using ..JulGame
    import ..JulGame: deprecated_get_property
    
    export SoundSource
    struct SoundSource
        channel::Int32
        isMusic::Bool
        path::String
        volume::Int32
    end

    export InternalSoundSource
    mutable struct InternalSoundSource
        channel::Int32
        isMusic::Bool
        parent::Any
        path::String
        sound::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2._Mix_Music}, Ptr{SDL2.LibSDL2.Mix_Chunk}}
        volume::Int32

        # Music
        function InternalSoundSource(parent::Any, path::String, channel::Int32, volume::Int32, isMusic::Bool)
            this = new()

            SDL2.SDL_ClearError()
            fullPath = joinpath(BasePath, "assets", "sounds", path)
            if length(path) < 1
                sound = C_NULL    
            else
                sound = isMusic ? SDL2.Mix_LoadMUS(fullPath) : SDL2.Mix_LoadWAV(fullPath)
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

            return this
        end
    end
    
    function Base.getproperty(this::InternalSoundSource, s::Symbol)
        method_props = (
            toggleSound = toggle_sound,
            stopMusic = stop_music,
            loadSound = load_sound,
            unloadSound = unload_sound,
            setParent = set_parent
        )
        deprecated_get_property(method_props, this, s)
    end

    function toggle_sound(this::InternalSoundSource, loops = 0)
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
    
    function stop_music(this::InternalSoundSource)
        SDL2.Mix_HaltMusic()
    end
    
    function load_sound(this::InternalSoundSource, soundPath::String, isMusic::Bool)
        this.isMusic = isMusic
        this.sound =  this.isMusic ? SDL2.Mix_LoadMUS(joinpath(BasePath, "assets", "sounds", soundPath)) : SDL2.Mix_LoadWAV(joinpath(BasePath, "assets", "sounds", soundPath))
        error = unsafe_string(SDL2.SDL_GetError())
        if !isempty(error)
            println(string("Couldn't open sound! SDL Error: ", error))
            SDL2.SDL_ClearError()
            this.sound = C_NULL
            return
        end
        this.path = soundPath
    end

    function unload_sound(this::InternalSoundSource)
        if this.isMusic
            SDL2.Mix_FreeMusic(this.sound)
        else
            SDL2.Mix_FreeChunk(this.sound)
        end
        this.sound = C_NULL
    end
    
    function set_parent(this::InternalSoundSource, parent::Any)
        this.parent = parent
    end

end
