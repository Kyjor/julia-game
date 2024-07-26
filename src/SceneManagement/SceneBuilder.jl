module SceneBuilderModule
    using ...JulGame
    using ...Math
    using ...ColliderModule
    using ...EntityModule
    using ...RigidbodyModule
    using ...TextBoxModule
    using ...ScreenButtonModule
    using ..SceneReaderModule
    import ...JulGame: deprecated_get_property

    function __init__()
        # if end of path is "test", then we are running tests
        if endswith(pwd(), "test")
            println("Loading scripts in test folder...")
            # TODO: reenable and run tests here in CI include.(filter(contains(r".jl$"), readdir(joinpath(pwd(), "projects", "ProfilingTest", "Platformer", "scripts"); join=true)))
            include.(filter(contains(r".jl$"), readdir(joinpath(pwd(), "projects", "SmokeTest", "scripts"); join=true)))
        end

        if isdir(joinpath(pwd(), "..", "scripts")) #dev builds
            println("Loading scripts...")
            include.(filter(contains(r".jl$"), readdir(joinpath(pwd(), "..", "scripts"); join=true)))
        else
            script_folder_name = "scripts"
            current_dir = pwd()
            
            # Find all folders in the current directory
            folders = filter(isdir, readdir(current_dir))
            
            # Check each folder for the "scripts" subfolder
            for folder in folders
                scripts_path = joinpath(current_dir, folder, script_folder_name)
                if isdir(scripts_path)
                    println("Loading scripts in $scripts_path...")
                    include.(filter(contains(r".jl$"), readdir(scripts_path; join=true)))
                    break  # Exit loop if "scripts" folder is found in any parent folder
                end
            end
        end
    end
        
    include("../Camera.jl")
    
    export Scene
    mutable struct Scene
        scene
        srcPath::String
        function Scene(sceneFileName::String, srcPath::String = joinpath(pwd(), ".."))
            this = new()  

            this.scene = sceneFileName
            this.srcPath = srcPath
            JulGame.BasePath = srcPath

            return this
        end    
    end
    
    function Base.getproperty(this::Scene, s::Symbol)
        method_props = (
            init = init,
            changeScene = change_scene,
            createNewEntity = create_new_entity,
            createNewTextBox = create_new_text_box,
            createNewScreenButton = create_new_screen_button
        )
        deprecated_get_property(method_props, this, s)
    end

    

    function init(this::Scene, main, windowName::String = "Game", isUsingEditor = false, size::Vector2 = Vector2(800, 800), camSize::Vector2 = Vector2(800,800), isResizable::Bool = true, zoom::Float64 = 1.0, autoScaleZoom::Bool = true, targetFrameRate = 60.0, globals = []; isNewEditor = false)
        #file loading
        if autoScaleZoom 
            zoom = 1.0
        end
        
        main.windowName = windowName
        main.zoom = zoom
        main.globals = globals
        main.level = this
        main.targetFrameRate = targetFrameRate
        scene = deserializeScene(joinpath(BasePath, "scenes", this.scene), isUsingEditor)
        main.scene.entities = scene[1]
        main.scene.uiElements = scene[2]
        if size.x < camSize.x && size.x > 0
            camSize = Vector2(size.x, camSize.y)
        end
        if size.y < camSize.y && size.y > 0
            camSize = Vector2(camSize.x, size.y)
        end
        main.scene.camera = Camera(camSize, Vector2f(),Vector2f(), C_NULL)
        
        for uiElement in main.scene.uiElements
            if "$(typeof(uiElement))" == "JulGame.UI.TextBoxModule.Textbox" && uiElement.isWorldEntity
                uiElement.centerText()
            end
        end

        main.scene.rigidbodies = InternalRigidbody[]
        main.scene.colliders = InternalCollider[]
        for entity in main.scene.entities
            if entity.rigidbody != C_NULL
                push!(main.scene.rigidbodies, entity.rigidbody)
            end
            if entity.collider != C_NULL
                push!(main.scene.colliders, entity.collider)
            end

            if !isUsingEditor
                scriptCounter = 1
                for script in entity.scripts
                    params = []
                    for param in script.parameters
                        if lowercase(param) == "true"
                            param = true
                        elseif lowercase(param) == "false"
                            param = false
                        else
                            try
                                param = occursin(".", param) == true ? parse(Float64, param) : parse(Int32, param)
                            catch e
                                println(e)
						        Base.show_backtrace(stdout, catch_backtrace())
						        rethrow(e)
                            end
                        end
                        push!(params, param)
                    end

                    newScript = C_NULL
                    try
                        newScript = eval(Symbol(script.name))(params...)
                    catch e
                        println(e)
						Base.show_backtrace(stdout, catch_backtrace())
						rethrow(e)
                    end

                    entity.scripts[scriptCounter] = newScript
                    newScript.setParent(entity)
                    scriptCounter += 1
                end
            end
        end

        main.assets = joinpath(BasePath, "assets")
        JulGame.MainLoop.init(main, isUsingEditor, size, isResizable, autoScaleZoom, isNewEditor)

        return main
    end

    function change_scene(this::Scene, main, isUsingEditor::Bool = false)
        scene = deserializeScene(joinpath(BasePath, "scenes", this.scene), isUsingEditor)
        
        # println("Changing scene to $this.scene")
        # println("Entities in main scene: ", length(main.scene.entities))

        for entity in scene[1]
            push!(main.scene.entities, entity)
        end

        main.scene.uiElements = scene[2]

        for uiElement in main.scene.uiElements
            if "$(typeof(uiElement))" == "JulGame.UI.TextBoxModule.Textbox" && uiElement.isWorldEntity
                uiElement.centerText()
            end
        end

        for entity in main.scene.entities
            if entity.persistentBetweenScenes
                continue
            end
            
            if entity.rigidbody != C_NULL
                push!(main.scene.rigidbodies, entity.rigidbody)
            end
            if entity.collider != C_NULL
                push!(main.scene.colliders, entity.collider)
            end

            if !isUsingEditor
                scriptCounter = 1
                for script in entity.scripts
                    params = []
                    if isa(script, Dict)
                        for param in script.parameters
                            
                            if lowercase(param) == "true"
                                param = true
                            elseif lowercase(param) == "false"
                                param = false
                            else
                                try
                                    param = occursin(".", param) == true ? parse(Float64, param) : parse(Int32, param)
                                catch e
                                    println(e)
                                    Base.show_backtrace(stdout, catch_backtrace())
                                    rethrow(e)
                                end
                            end
                            push!(params, param)
                        end
                    end

                    newScript = C_NULL
                    try
                        newScript = eval(Symbol(script.name))(params...)
                    catch e
                        println(e)
						Base.show_backtrace(stdout, catch_backtrace())
						rethrow(e)
                    end

                    if newScript != C_NULL
                        entity.scripts[scriptCounter] = newScript
                        newScript.setParent(entity)
                    end
                    scriptCounter += 1
                end
            end
        end 
    end

    """
    create_new_entity(this::Scene)

    Create a new entity and add it to the scene.

    # Arguments
    - `this::Scene`: The scene object to which the entity will be added.

    """
    function create_new_entity(this::Scene, main)
        push!(main.scene.entities, Entity("New entity"))
    end

    function create_new_text_box(this::Scene, main)
        textBox = TextBox("TextBox", "", 40, Vector2(0, 200), "TextBox", true, true)
        JulGame.initialize(textBox)
        push!(main.scene.uiElements, textBox)
    end
    
    function create_new_screen_button(this::Scene, main)
        screenButton = ScreenButton("name", "ButtonUp.png", "ButtonDown.png", Vector2(256, 64), Vector2(0, 0), joinpath("FiraCode", "ttf", "FiraCode-Regular.ttf"), "test")
        JulGame.initialize(screenButton)
        push!(main.scene.screenButtons, screenButton)
        push!(main.scene.uiElements, screenButton)
    end
end
