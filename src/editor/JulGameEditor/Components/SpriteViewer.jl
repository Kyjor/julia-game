using CImGui
using CImGui: ImVec2, ImVec4, IM_COL32, ImU32
using CImGui.CSyntax
using CImGui.CSyntax.CFor
using CImGui.CSyntax.CStatic

function load_texture_from_file(filename::String, renderer::Ptr{SDL2.SDL_Renderer})
    width = Ref{Cint}()
    height = Ref{Cint}()
    channels = Ref{Cint}()
    
    surface = SDL2.IMG_Load(filename)
    if surface == C_NULL
        @error "Failed to load image: $(unsafe_string(SDL2.SDL_GetError()))"
        return false, C_NULL, 0, 0
    end
    
    surfaceInfo = unsafe_wrap(Array, surface, 10; own = false)
    width[] = surfaceInfo[1].w
    height[] = surfaceInfo[1].h

    if surface == C_NULL
        @error "Failed to create SDL surface: $(unsafe_string(SDL2.SDL_GetError()))"
        return false, C_NULL, 0, 0
    end
    
    texture_ptr = SDL2.SDL_CreateTextureFromSurface(renderer, surface)
    
    if texture_ptr == C_NULL
        @error "Failed to create SDL texture: $(unsafe_string(SDL2.SDL_GetError()))"
    end
    
    SDL2.SDL_FreeSurface(surface)
    
    return true, texture_ptr, width[], height[] #, data
end


"""
    ShowExampleAppCustomRendering(p_open::Ref{Bool})
Demonstrate using the low-level ImDrawList to draw custom shapes.
"""
function show_animation_window(frame_name, window_info, my_tex_id, my_tex_w, my_tex_h)
    CImGui.SetNextWindowSize((350, 560), CImGui.ImGuiCond_FirstUseEver)
    CImGui.Begin("Animation - $(frame_name)") || (CImGui.End(); return)

    draw_list = CImGui.GetWindowDrawList()
    io = CImGui.GetIO()
        
    # UI elements
    # grid step int input as slider with range. Min = 1, Max = 64
    CImGui.SliderInt("Grid step", window_info[]["grid_step"], 1, 64, "%d")
    CImGui.Text("Mouse Left: drag to add square,\nMouse Right: drag to scroll, click for context menu.\nCTRL+Mouse Wheel: zoom")
    selectedPoint1 = length(window_info[]["points"][]) > 0 ? window_info[]["points"][][end-1] : ImVec2(0,0)
    selectedPoint2 = length(window_info[]["points"][]) > 0 ? window_info[]["points"][][end] : ImVec2(0,0)
    CImGui.Text("Current selection: x:$(selectedPoint1.x),y:$(selectedPoint1.y) w:$(selectedPoint2.x - selectedPoint1.x),h:$(selectedPoint2.y - selectedPoint1.y)")
    # Canvas setup
    canvas_p0 = CImGui.GetCursorScreenPos()  # ImDrawList API uses screen coordinates!
    canvas_sz = CImGui.GetContentRegionAvail()  # Resize canvas to what's available
    canvas_sz = ImVec2(max(canvas_sz.x, 50.0), max(canvas_sz.y, 50.0))
    canvas_p1 = ImVec2(canvas_p0.x + canvas_sz.x, canvas_p0.y + canvas_sz.y)

    canvas_max = ImVec2(my_tex_w * 10, my_tex_h * 10)

    # Draw border and background color
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRectFilled(draw_list, canvas_p0, canvas_p1, IM_COL32(50, 50, 50, 255))
    CImGui.AddRect(draw_list, canvas_p0, canvas_p1, IM_COL32(255, 255, 255, 255))

    # Draw border around actual image that is being edited TODO: Fix this
    # CImGui.AddRect(draw_list, ImVec2(canvas_p0.x + (my_tex_w * window_info[]["zoom_level"][]), canvas_p0.y + (my_tex_h * window_info[]["zoom_level"][])), ImVec2(canvas_p0.x, canvas_p0.y), IM_COL32(255, 255, 255, 255))

    # Invisible button for interactions
    CImGui.InvisibleButton("canvas", canvas_sz, CImGui.ImGuiButtonFlags_MouseButtonLeft | CImGui.ImGuiButtonFlags_MouseButtonRight)
    is_hovered = CImGui.IsItemHovered()  # Hovered
    is_active = CImGui.IsItemActive()  # Held
    # origin = ImVec2(canvas_p0.x + window_info[]["scrolling"][].x, canvas_p0.y + window_info[]["scrolling"][].y)  # Lock scrolled origin
    window_info[]["scrolling"][] = ImVec2(min(window_info[]["scrolling"][].x, 0.0), min(window_info[]["scrolling"][].y, 0.0))
    window_info[]["scrolling"][] = ImVec2(max(window_info[]["scrolling"][].x, -canvas_max.x), max(window_info[]["scrolling"][].y, -canvas_max.y))
    origin = ImVec2(min(0, 0 + window_info[]["scrolling"][].x), min(0, 0 + window_info[]["scrolling"][].y))  # Lock scrolled origin
    mouse_pos_in_canvas = ImVec2(unsafe_load(io.MousePos).x - canvas_p0.x, unsafe_load(io.MousePos).y - canvas_p0.y)
    CImGui.Text("Mouse Position: $(mouse_pos_in_canvas.x), $(mouse_pos_in_canvas.y)")
    CImGui.Text("Mouse Pixel: $(floor(mouse_pos_in_canvas.x / window_info[]["zoom_level"][])), $(floor(mouse_pos_in_canvas.y / window_info[]["zoom_level"][]))")

    mouse_pos_in_canvas_zoom_adjusted = ImVec2(floor(mouse_pos_in_canvas.x / window_info[]["zoom_level"][]), floor(mouse_pos_in_canvas.y / window_info[]["zoom_level"][]))
    #rounded = ImVec2(round(mouse_pos_in_canvas_zoom_adjusted.x/ window_info[]["zoom_level"][]) * window_info[]["zoom_level"][], round(mouse_pos_in_canvas_zoom_adjusted.y/ window_info[]["zoom_level"][]) * window_info[]["zoom_level"][])
    # Add first and second point
    if is_hovered && !window_info[]["adding_line"][] && CImGui.IsMouseClicked(CImGui.ImGuiMouseButton_Left)
        push!(window_info[]["points"][], mouse_pos_in_canvas_zoom_adjusted)
        push!(window_info[]["points"][], mouse_pos_in_canvas_zoom_adjusted)
        window_info[]["adding_line"][] = true
    end
    if window_info[]["adding_line"][]
        window_info[]["points"][][end] = mouse_pos_in_canvas_zoom_adjusted
        if !CImGui.IsMouseDown(CImGui.ImGuiMouseButton_Left)
            window_info[]["points"][] = [window_info[]["points"][][end-1], window_info[]["points"][][end]] # only keep last two points
            window_info[]["adding_line"][] = false
        end
    end

    # Pan
    mouse_threshold_for_pan = -1.0 
    if is_active && CImGui.IsMouseDragging(CImGui.ImGuiMouseButton_Right, mouse_threshold_for_pan)
        window_info[]["scrolling"][] = ImVec2(window_info[]["scrolling"][].x + unsafe_load(io.MouseDelta).x, window_info[]["scrolling"][].y + unsafe_load(io.MouseDelta).y)
    end

    # Zoom
    if unsafe_load(io.KeyCtrl)
        window_info[]["zoom_level"][] += unsafe_load(io.MouseWheel) * 4.0 # * 0.10
        window_info[]["zoom_level"][] = clamp(window_info[]["zoom_level"][], 1.0, 50.0)
    end

    # Context menu
    drag_delta = CImGui.GetMouseDragDelta(CImGui.ImGuiMouseButton_Right)
    if CImGui.IsMouseReleased(CImGui.ImGuiMouseButton_Right) && drag_delta.x == 0.0 && drag_delta.y == 0.0
        CImGui.OpenPopupOnItemClick("context")
    end
    if CImGui.BeginPopup("context")
        if window_info[]["adding_line"][]
            resize!(window_info[]["points"][], length(window_info[]["points"][]) - 2)
        end
        window_info[]["adding_line"][] = false
        if CImGui.MenuItem("Remove one", "", false, length(window_info[]["points"][]) > 0)
            resize!(window_info[]["points"][], length(window_info[]["points"][]) - 2)
        end
        if CImGui.MenuItem("Remove all", "", false, length(window_info[]["points"][]) > 0)
            empty!(window_info[]["points"][])
        end
        CImGui.EndPopup()
    end

    # Draw grid and lines
    CImGui.PushClipRect(draw_list, canvas_p0, canvas_p1, true)
        GRID_STEP = window_info[]["grid_step"][] * window_info[]["zoom_level"][]

        for x in 0:GRID_STEP:canvas_sz.x*10 # TODO: 10 is arbitrary
            CImGui.AddLine(draw_list, ImVec2(origin.x + canvas_p0.x + x, canvas_p0.y), ImVec2(origin.x + canvas_p0.x + x, canvas_p1.y), IM_COL32(200, 200, 200, 40))
        end
        for y in 0:GRID_STEP:canvas_sz.y*10 # TODO: 10 is arbitrary
            CImGui.AddLine(draw_list, ImVec2(canvas_p0.x, origin.y + canvas_p0.y + y), ImVec2(canvas_p1.x, origin.y + canvas_p0.y + y), IM_COL32(200, 200, 200, 40))
        end
    
    # Draw squares with add rect 
    for n in 1:2:length(window_info[]["points"][])-1
        p1 = ImVec2(origin.x + canvas_p0.x + (window_info[]["points"][][n].x * window_info[]["zoom_level"][]), origin.y + canvas_p0.y + (window_info[]["points"][][n].y * window_info[]["zoom_level"][]))
        p2 = ImVec2(origin.x + canvas_p0.x + (window_info[]["points"][][n+1].x * window_info[]["zoom_level"][]), origin.y + canvas_p0.y + (window_info[]["points"][][n+1].y * window_info[]["zoom_level"][]))
        # scale to zoom level
        CImGui.AddRect(draw_list, p1, p2, IM_COL32(255, 255, 0, 255))
    end

    CImGui.AddImage(draw_list, my_tex_id, ImVec2(origin.x + canvas_p0.x, origin.y + canvas_p0.y), ImVec2(origin.x + (my_tex_w * window_info[]["zoom_level"][]) + canvas_p0.x, origin.y + (my_tex_h * window_info[]["zoom_level"][]) + canvas_p0.y), ImVec2(0,0), ImVec2(1,1), IM_COL32(255,255,255,255))
    CImGui.PopClipRect(draw_list)

    CImGui.End()

    # x, y, w, h = crop.x, crop.y, crop.z, crop.t
    return selectedPoint1.x, selectedPoint1.y, selectedPoint2.x - selectedPoint1.x, selectedPoint2.y - selectedPoint1.y
end

function show_image_with_hover_preview(my_tex_id, my_tex_w, my_tex_h, crop)
    io = CImGui.GetIO()

    x, y, w, h = crop.x, crop.y, crop.z, crop.t
    W, H = my_tex_w, my_tex_h  # dimensions of the texture or image
    
    u1, v1, u2, v2 = rect_to_uv(x, y, w, h, W, H)
    crop = true
    if u1 == 0 && v1 == 0 && u2 == 0 && v2 == 0
        u1, v1 = 0, 0
        u2, v2 = 1, 1
        crop = false
        return
    else
        my_tex_w = w
        my_tex_h = h
    end

    # CImGui.Text("$(my_tex_w)x$(my_tex_h)")
    pos = CImGui.GetCursorScreenPos()
    CImGui.Image(my_tex_id, ImVec2(my_tex_w, my_tex_h), (u1,v1), (u2,v2), (255,255,255,255), (255,255,255,128))
    if CImGui.IsItemHovered() && unsafe_load(io.KeyShift)
        CImGui.BeginTooltip()
        region_sz = min(32.0, min(my_tex_w, my_tex_h))
        region_x = unsafe_load(io.MousePos).x - pos.x - region_sz * 0.5
        if region_x < 0.0
            region_x = 0.0
        elseif region_x > my_tex_w - region_sz
            region_x = my_tex_w - region_sz
        end
        region_y = unsafe_load(io.MousePos).y - pos.y - region_sz * 0.5
        if region_y < 0.0
            region_y = 0.0
        elseif region_y > my_tex_h - region_sz
            region_y = my_tex_h - region_sz
        end
        zoom = 4.0
        CImGui.Text("Min: ($(region_x), $(region_y))")
        CImGui.Text("Max: ($(region_x + region_sz), $(region_y + region_sz))")
        uv0 = ImVec2((region_x) / my_tex_w, (region_y) / my_tex_h)
        uv1 = ImVec2((region_x + region_sz) / my_tex_w, (region_y + region_sz) / my_tex_h)
        if crop
            uv0 = (u1,v1)
            uv1 = (u2,v2)
        end
        CImGui.Image(my_tex_id, ImVec2(region_sz * zoom, region_sz * zoom), uv0, uv1, (255,255,255,255), (255,255,255,128))
        CImGui.EndTooltip()
    end
    CImGui.SameLine()
end

function rect_to_uv(x, y, w, h, W, H)
    # Start UV coordinates (top-left)
    u1 = x / W
    v1 = y / H
    
    # End UV coordinates (bottom-right)
    u2 = (x + w) / W
    v2 = (y + h) / H
    
    return u1, v1, u2, v2
end

