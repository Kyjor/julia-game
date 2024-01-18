
module Editor
    using CImGui
    using CImGui.CSyntax
    using CImGui.CSyntax.CStatic
    using CImGui: ImVec2, ImVec4, IM_COL32, ImS32, ImU32, ImS64, ImU64, LibCImGui
    using Dates
    using NativeFileDialog
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer
    using ImGuiOpenGLBackend #CImGui.OpenGLBackend
    using ImGuiOpenGLBackend.ModernGL
    #using Printf
    using JulGame
    using JulGame.EntityModule
    using JulGame.SceneWriterModule
    using JulGame.SceneLoaderModule
    using JulGame.TextBoxModule
    global sdlVersion = "2.0.0"
    include("../../Macros.jl")
    include("./MainMenuBar.jl")
    include("./EntityContextMenu.jl")
    include("./ComponentInputs.jl")
    include("./TextBoxFields.jl")
    include("./Utils.jl")
    include("SDL_Backend.jl")


function run()
    if SDL2.SDL_Init(SDL2.SDL_INIT_VIDEO) < 0
        println("failed to init: ", unsafe_string(SDL2.SDL_GetError()));
    end
    @static if Sys.isapple()
        # OpenGL 3.2 + GLSL 150
        # GL 3.2 Core + GLSL 150
        glsl_version = 150
        SDL2.SDL_GL_SetAttribute(SDL2.SDL_GL_CONTEXT_FLAGS, SDL2.SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG); # Always required on Mac
        SDL2.SDL_GL_SetAttribute(SDL2.SDL_GL_CONTEXT_PROFILE_MASK, SDL2.SDL_GL_CONTEXT_PROFILE_CORE);
        SDL2.SDL_GL_SetAttribute(SDL2.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
        SDL2.SDL_GL_SetAttribute(SDL2.SDL_GL_CONTEXT_MINOR_VERSION, 2);
    else
        # GL 3.0 + GLSL 130
        glsl_version = 130;
        SDL2.SDL_GL_SetAttribute(SDL2.SDL_GL_CONTEXT_FLAGS, 0);
        SDL2.SDL_GL_SetAttribute(SDL2.SDL_GL_CONTEXT_PROFILE_MASK, SDL2.SDL_GL_CONTEXT_PROFILE_CORE);
        SDL2.SDL_GL_SetAttribute(SDL2.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
        SDL2.SDL_GL_SetAttribute(SDL2.SDL_GL_CONTEXT_MINOR_VERSION, 0);
    end
    
    # and prepare OpenGL stuff
    SDL2.SDL_SetHint(SDL2.SDL_HINT_RENDER_DRIVER, "opengl")
    SDL2.SDL_GL_SetAttribute(SDL2.SDL_GL_DEPTH_SIZE, 24)
    SDL2.SDL_GL_SetAttribute(SDL2.SDL_GL_STENCIL_SIZE, 8)
    SDL2.SDL_GL_SetAttribute(SDL2.SDL_GL_DOUBLEBUFFER, 1)
    current = SDL2.SDL_DisplayMode[SDL2.SDL_DisplayMode(0x12345678, 800, 600, 60, C_NULL)]
	SDL2.SDL_GetCurrentDisplayMode(0, pointer(current))
	dimensions = Math.Vector2(current[1].w, current[1].h)
    
    window = SDL2.SDL_CreateWindow(
      "JulGame Editor v0.1.0", SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, 1024, 768,
      SDL2.SDL_WINDOW_SHOWN | SDL2.SDL_WINDOW_OPENGL | SDL2.SDL_WINDOW_RESIZABLE
      )
    if window == C_NULL 
        println("Failed to create window: ", unsafe_string(SDL2.SDL_GetError()))
        return -1
    end

    renderer = SDL2.SDL_CreateRenderer(window, -1, SDL2.SDL_RENDERER_ACCELERATED)
    gl_context = SDL2.SDL_GL_CreateContext(window);
    SDL2.SDL_GL_SetSwapInterval(1);  # enable vsync


  # check opengl version sdl uses
  #SDL_Log("opengl version: %s", glGetString(GL_VERSION));
  ver = pointer(SDL2.SDL_version[SDL2.SDL_version(0,0,0)])
    SDL2.SDL_GetVersion(ver)
    global sdlVersion = string(unsafe_load(ver).major, ".", unsafe_load(ver).minor, ".", unsafe_load(ver).patch)
    println("SDL version: ", sdlVersion)
    sdlVersion = parse(Int32, replace(sdlVersion, "." => ""))

    ctx = CImGui.CreateContext()
    
    io = CImGui.GetIO()
    io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_DockingEnable | CImGui.ImGuiConfigFlags_NavEnableKeyboard | CImGui.ImGuiConfigFlags_NavEnableGamepad

    io.BackendPlatformUserData = C_NULL
    #TODO: THISSSS
    ImGui_ImplSDL2_InitForSDLRenderer(window, renderer);
    opengl_ctx = ImGuiOpenGLBackend.create_context(glsl_version)
    ImGuiOpenGLBackend.init(opengl_ctx)
    
    # setup Dear ImGui style #Todo: Make this a setting
    CImGui.StyleColorsDark()
    # CImGui.StyleColorsClassic()
    # CImGui.StyleColorsLight()
    
    showDemoWindow = true
    showAnotherWindow = false
    clear_color = Cfloat[0.45, 0.55, 0.60, 0.01]
    
    
    
    quit = false
        try
            while !quit
                event_ref = Ref{SDL2.SDL_Event}()
                while Bool(SDL2.SDL_PollEvent(event_ref))
                    evt = event_ref[]
                    ImGui_ImplSDL2_ProcessEvent(evt)
                    evt_ty = evt.type
                    if evt_ty == SDL2.SDL_QUIT
                        quit = true
                        break
                    elseif evt_ty == SDL2.SDL_KEYDOWN
                        scan_code = evt.key.keysym.scancode
                        if scan_code == SDL2.SDL_SCANCODE_W || scan_code == SDL2.SDL_SCANCODE_UP
                            break
                        elseif scan_code == SDL2.SDL_SCANCODE_A || scan_code == SDL2.SDL_SCANCODE_LEFT
                            break
                        elseif scan_code == SDL2.SDL_SCANCODE_S || scan_code == SDL2.SDL_SCANCODE_DOWN
                            break
                        elseif scan_code == SDL2.SDL_SCANCODE_D || scan_code == SDL2.SDL_SCANCODE_RIGHT
                            break
                        else
                            break
                        end
                    end
                end
                    
                #     // start imgui frame
                ImGuiOpenGLBackend.new_frame(opengl_ctx) #ImGui_ImplOpenGL3_NewFrame()
                ImGui_ImplSDL2_NewFrame();
                CImGui.NewFrame()

                LibCImGui.igDockSpaceOverViewport(C_NULL, ImGuiDockNodeFlags_PassthruCentralNode, C_NULL) # Creating the "dockspace" that covers the whole window. This allows the child windows to automatically resize.
                @c CImGui.ShowDemoWindow(Ref{Bool}(showDemoWindow))

                @cstatic begin
                    CImGui.Begin("Controls")  
                    CImGui.Text("Pan scene: Arrow keys/Hold middle mouse button and move mouse")
                    CImGui.NewLine()
                    CImGui.Text("Zoom in/out: Hold spacebar and left and right arrow keys")
                    CImGui.NewLine()
                    CImGui.Text("Select entity: Click on entity in scene window or in hierarchy window")
                    CImGui.NewLine()
                    CImGui.Text("Move entity: Hold left mouse button and drag entity")
                    CImGui.NewLine()
                    CImGui.Text("Duplicate entity: Select entity and click 'Duplicate' in hierarchy window or press 'LCTRL+D' keys")
                    CImGui.NewLine()
                    CImGui.End()
                end

                CImGui.Render()

                width, height = Ref{Cint}(), Ref{Cint}()
                SDL2.SDL_GL_MakeCurrent(window, gl_context);
                
                #println(unsafe_load(io.DisplaySize.x), "x", unsafe_load(io.DisplaySize.y))
                glViewport(0, 0, 1280, 720)
                glClearColor(clear_color...)
                glClear(GL_COLOR_BUFFER_BIT)
                ImGuiOpenGLBackend.render(opengl_ctx) #ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())
                # #ifdef IMGUI_HAS_DOCK
                # 	if (ioptr->ConfigFlags & ImGuiConfigFlags_ViewportsEnable)
                #         {
                #             SDL_Window* backup_current_window = SDL_GL_GetCurrentWindow();
                #             SDL_GLContext backup_current_context = SDL_GL_GetCurrentContext();
                #             igUpdatePlatformWindows();
                #             igRenderPlatformWindowsDefault(NULL,NULL);
                #             SDL_GL_MakeCurrent(backup_current_window, backup_current_context);
                #         }
                # #endif
                SDL2.SDL_GL_SwapWindow(window);
            end
        catch e
            @warn "Error in renderloop!" exception=e
            Base.show_backtrace(stderr, catch_backtrace())
        finally
            #   ImGui_ImplSDL2_Shutdown();
            SDL2.SDL_GL_DeleteContext(gl_context);
            #     window = NULL;
            ImGuiOpenGLBackend.shutdown(opengl_ctx) #ImGui_ImplOpenGL3_Shutdown()
            CImGui.DestroyContext(ctx)
            SDL2.SDL_DestroyWindow(window);
            SDL2.SDL_Quit()
    end
  # ================ CUT OFF
  SDL2.SDL_Quit()
  # ================ CUT OFF
end
  




end