module julGame
    include("Math/Math.jl")
    using .Math: Math
    export Math

    include("Input/InputInstance.jl")
    using .InputInstance: Input
    export Input

    include("Main.jl") 
    using .MainLoop: Main   
    const MAIN = Main(2.0)
    #export MainLoop
    export MAIN

    export Component
    include("Component/Component.jl")
    using .Component
    export AnimationModule, AnimatorModule, ColliderModule, RigidbodyModule, SoundSourceModule, SpriteModule, TransformModule

    include("Entity.jl") 
    using .EntityModule   
    export Entity

    export SceneManagement
    include("SceneManagement/SceneManagement.jl")
    using .SceneManagement
    export SceneBuilderModule, SceneReaderModule, SceneWriterModule 

    export SceneManagement
    include("../Editor/editor.jl")
    using .Editor
    export Editor 
end