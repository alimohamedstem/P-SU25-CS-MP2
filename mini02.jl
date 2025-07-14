include("plot_graph.jl")
include("scoring.jl")
using Makie.Colors
using Random
using StatsBase
using Colors

# Suppress all @show statements
# import Base.@show
# macro show(x) end

# Suppress all println statements
# import Base.println
# println(args...) = nothing

mutable struct NodeInfo
    label::Int
    neighbors::Vector{Int}
end

#=
> Shuffle the nodes.
> Iterate through the nodes.
>   Change the current node's label to the neighbor's label that increases the score the most.
>   (Break ties at random, and skip the node if no label change improves the score.)
>   
=#

function our_algorithm(g, node_info)
    shuffled_nodes = shuffle(1:nv(g))
    current_colors = [node_info[k].label for k in 1:nv(g)]
    current_score = get_score(g, node_info, current_colors)
    changes_made = 0

    for n in shuffled_nodes
        score_changes = Dict{Int,Float64}()  # Changed to Float64 for score values

        for nbr in node_info[n].neighbors
            # Create a temporary copy of node_info to test the change
            temp_node_info = deepcopy(node_info)
            temp_node_info[n].label = node_info[nbr].label
            temp_colors = [temp_node_info[k].label for k in 1:nv(g)]
            score_changes[node_info[nbr].label] = get_score(g, temp_node_info, temp_colors) - current_score
        end

        if !isempty(score_changes)
            max_change = maximum(values(score_changes))
            if max_change > 0
                keys_at_max = [key for (key, value) in score_changes if value == max_change]
                best_label = rand(keys_at_max)
                old_label = node_info[n].label
                node_info[n].label = best_label
                changes_made += 1
                println("Node $n: $old_label -> $best_label (score change: $max_change)")
                # Update current_score for next iteration
                current_colors = [node_info[k].label for k in 1:nv(g)]
                current_score = get_score(g, node_info, current_colors)
            end
        end
    end
    println("Total changes made: $changes_made")
end

function label_propagation(g, node_info)
    label_changed = true

    while label_changed
        label_changed = false
        shuffled_nodes = shuffle(1:nv(g))

        for u in shuffled_nodes
            original_label = node_info[u].label
            current_colors = [node_info[k].label for k in 1:nv(g)]
            current_score = get_score(g, node_info, current_colors)

            score_changes = Dict{Int,Float64}()

            for v in node_info[u].neighbors
                temp_label = node_info[v].label
                node_info[u].label = temp_label
                temp_colors = [node_info[k].label for k in 1:nv(g)]
                new_score = get_score(g, node_info, temp_colors)
                score_changes[temp_label] = new_score - current_score
            end

            node_info[u].label = original_label

            max_change = maximum(values(score_changes))
            if max_change > 0
                best_labels = [label for (label, score) in score_changes if score == max_change]
                node_info[u].label = maximum(best_labels)
                label_changed = true
            end

        end
        current_labels = [node_info[k].label for k in 1:nv(g)]
        current_final_score = get_score(g, node_info, current_labels)
        most_common_node = mode(current_labels)
        for k in 1:nv(g)
            node_info[k].label = most_common_node
        end
        new_colors = [node_info[k].label for k in 1:nv(g)]
        new_score = get_score(g, node_info, new_colors)
        if new_score > current_final_score
            label_changed = true
        else
            for k in 1:nv(g)
                node_info[k].label = current_labels[k]
            end
        end
    end
end



function main(filename="graph06.txt")
    edge_list = read_edges(filename)
    g = build_graph(edge_list)

    # Build a dictionary mapping node indices to the node's info
    node_info = Dict{Int,NodeInfo}()
    for n in 1:nv(g)
        node_info[n] = NodeInfo(n, collect(neighbors(g, n)))
    end

    label_propagation(g, node_info)

    # Use a fixed-size color palette for cycling, e.g., 16 colors
    palette_size = 16
    color_palette = Makie.distinguishable_colors(palette_size)

    # Assign initial color indices based on label AFTER running algorithms
    labels = unique([node.label for node in values(node_info)])
    label_to_color_index = Dict(labels[i] => mod1(i, palette_size) for i in eachindex(labels))
    node_color_indices = [label_to_color_index[node_info[n].label] for n in 1:nv(g)]
    node_colors = [color_palette[i] for i in node_color_indices]
    node_text_colors = [Colors.Lab(RGB(c)).l > 50 ? :black : :white for c in node_colors]

    interactive_plot_graph(g, node_info, node_colors, node_text_colors, node_color_indices, color_palette, label_to_color_index)
end

main()
