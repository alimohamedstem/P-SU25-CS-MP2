#=
Ash's score function
=#

function get_score(g, node_info, node_color_indices)

    labels = [(node, info.label) for (node, info) in node_info]
    label_groups = Dict{Int, Vector{Int}}()
    for (node, label) in labels
        push!(get!(label_groups, label, Int[]), node)
    end
    communities = collect(values(label_groups))

    t = length(communities)
    total_score = 0.0

    for (i, community) in enumerate(communities)
        println("\nGroup $i: ", community)

        internal_edges = Set{Tuple{Int, Int}}()
        for i in eachindex(community), j in (i+1):length(community)
            u, v = community[i], community[j]
            if has_edge(g, u, v)
                push!(internal_edges, (min(u, v), max(u, v)))
            end
        end
        println("  Internal edges: ", collect(internal_edges))

        max_internal = length(community) * (length(community) - 1) / 2

        external_edges = Set{Tuple{Int, Int}}()
        for u in community
            for v in neighbors(g, u)
                if v ∉ community
                    push!(external_edges, (min(u, v), max(u, v)))
                end
            end
        end
        println("  External edges: ", collect(external_edges))

        external_possible = length(community) * (nv(g) - length(community))
        internal_ratio = max_internal == 0 ? 0.0 : length(internal_edges) / max_internal
        external_ratio = external_possible == 0 ? 0.0 : length(external_edges) / external_possible
#finally here i intergrate the internal calc and external calc together to my scoring formula excluding deviding it by the total goups t
        group_score = internal_ratio * (1 - external_ratio)
        println("  Group score: ", round(group_score, digits=3))

        total_score += group_score
    end

    final_score = total_score / t
    println("\nScore: ", round(final_score, digits=3))
    return final_score
end