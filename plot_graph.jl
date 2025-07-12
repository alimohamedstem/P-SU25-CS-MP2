#= 
Written entirely by Copilot and GPT 4.1, this script reads a text file where 
each line is an edge ("x y") and then displays the graph using GraphMakie.
=#
using Graphs
using GraphMakie
using GLMakie
using GeometryBasics
using LinearAlgebra: norm
const Point2f0 = GeometryBasics.Point2f
import Graphs: edges

function read_edges(filename)
    edge_list = []
    open(filename, "r") do f
        for line in eachline(f)
            s = split(strip(line))
            if length(s) == 2 && all(x -> occursin(r"^\d+$", x), s)
                push!(edge_list, (parse(Int, s[1]), parse(Int, s[2])))
            end
        end
    end
    return edge_list
end

function build_graph(edges)
    if isempty(edges)
        println("No edges found in input file. Displaying an empty graph.")
        return SimpleGraph(0)
    end
    nodes = unique(vcat([e[1] for e in edges], [e[2] for e in edges]))
    g = SimpleGraph(maximum(nodes))
    for (u, v) in edges
        add_edge!(g, u, v)
    end
    return g
end

function interactive_plot_graph(g, node_info, node_colors, node_text_colors, node_color_indices, color_palette, label_to_color_index)
    n = nv(g)
    edges = collect(Graphs.edges(g))
    width, height = 800, 600
    cx, cy = width/2, height/2
    radius = min(width, height) * 0.4
    positions = Observable([Point2f0(cx + radius * cos(2π*i/n), cy + radius * sin(2π*i/n)) for i in 1:n])

    # Use an Observable for node colors to allow interactive updates
    node_colors_obs = Observable(copy(node_colors))
    node_color_indices_obs = Observable(copy(node_color_indices))
    node_text_colors_obs = Observable(copy(node_text_colors))
    
    # Create reverse mapping from color index to label
    color_index_to_label = Dict(v => k for (k, v) in label_to_color_index)

    scene = Scene(size = (width, height), camera = campixel!)
    # Observable for score, initialize with the correct score
    initial_score = get_score(g, node_info, node_color_indices)
    score_obs = Observable(initial_score)
    # Display score in the plot window (top left)
    text!(scene, lift(s -> "Score: $(s)", score_obs), position=Point2f0(20, height-30), align=(:left, :center), color=:black, fontsize=28)

    # Plot edges
    [lines!(scene, lift(pos -> [pos[src(e)], pos[dst(e)]], positions), color=:gray, linewidth=2) for e in edges]
    # Plot nodes as scatter, use node_colors_obs directly
    scatter!(scene, lift(pos -> first.(pos), positions), lift(pos -> last.(pos), positions),
        color=node_colors_obs, strokewidth=2, strokecolor=:black, markersize=60)
    # Plot labels, use node_text_colors_obs for each node
    [text!(scene, string(i), position=lift(pos -> pos[i], positions), align=(:center, :center), color=lift(_ -> node_text_colors_obs[][i], node_text_colors_obs), fontsize=18) for i in 1:n]

    # Dragging state
    dragging = Observable(false)
    drag_idx = Observable(0)
    last_mousepos = Observable(Point2f0(0, 0))
    mouse_down_pos = Observable(Point2f0(0, 0))
    mouse_down_node = Observable(0)
    moved = Observable(false)

    on(scene.events.mouseposition) do pos
        last_mousepos[] = Point2f0(pos[1], pos[2])
        if dragging[] && drag_idx[] > 0
            # Only start moving if the mouse has moved more than a threshold
            if !moved[] && norm(last_mousepos[] .- mouse_down_pos[]) > 5
                moved[] = true
            end
            if moved[]
                mousepos = last_mousepos[]
                newpos = copy(positions[])
                newpos[drag_idx[]] = mousepos
                positions[] = newpos
            end
        end
    end

    on(scene.events.mousebutton) do event
        if event.button == Mouse.left || event.button == Mouse.right
            if event.action == Mouse.press
                mousepos = last_mousepos[]
                for i in 1:n
                    if norm(mousepos .- positions[][i]) < 30  # 30 pixels for easier selection
                        dragging[] = true
                        drag_idx[] = i
                        mouse_down_pos[] = mousepos
                        mouse_down_node[] = i
                        moved[] = false
                        break
                    end
                end
            elseif event.action == Mouse.release
                if dragging[] && drag_idx[] > 0
                    # Only cycle color if not moved and press/release on same node
                    if !moved[] && mouse_down_node[] == drag_idx[]
                        idx = drag_idx[]
                        # Cycle the color index forward or backward
                        new_color_indices = copy(node_color_indices_obs[])
                        if event.button == Mouse.left
                            new_color_indices[idx] = mod1(new_color_indices[idx] + 1, length(color_palette))
                        elseif event.button == Mouse.right
                            new_color_indices[idx] = mod1(new_color_indices[idx] - 1, length(color_palette))
                        end
                        node_color_indices_obs[] = new_color_indices
                        # Update node colors from indices
                        new_colors = copy(node_colors_obs[])
                        new_colors[idx] = color_palette[new_color_indices[idx]]
                        node_colors_obs[] = new_colors
                        # Update node text color for this node
                        new_text_colors = copy(node_text_colors_obs[])
                        new_text_colors[idx] = Colors.Lab(RGB(new_colors[idx])).l > 50 ? :black : :white
                        node_text_colors_obs[] = new_text_colors
                        # Update the node_info label to match the actual label (not color index)
                        actual_label = get(color_index_to_label, new_color_indices[idx], new_color_indices[idx])
                        node_info[idx].label = actual_label
                        # Update score using the updated node_info
                        current_color_indices = [node_info[i].label for i in 1:length(node_info)]
                        score = get_score(g, node_info, current_color_indices)
                        score_obs[] = score
                    end
                end
                dragging[] = false
                drag_idx[] = 0
                mouse_down_node[] = 0
                moved[] = false
            end
        end
    end

    println("You can view the graph now!")
    display(scene)
    return scene
end