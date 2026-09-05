# Generates llms.txt and llms-full.txt alongside the built documentation,
# following the https://llmstxt.org convention: llms.txt indexes the pages,
# llms-full.txt concatenates their full text. Both land in the build directory
# so they are deployed with the site.

const SITE = "https://s-celles.github.io/JuliaupDistributions.jl/stable"

const SUMMARY = """
JuliaupDistributions publishes the static files a juliaup client reads, so a \
Julia distribution can be installed with `juliaup add <channel>` from any \
static host.
"""

function page_title(path, fallback)
    for line in eachline(path)
        startswith(line, "# ") && return strip(line[3:end])
    end
    return fallback
end

function generate_llms_txt(build_dir, source_dir, pages)
    entries = Tuple{String, String, String}[]

    for (label, file) in pages
        path = joinpath(source_dir, file)
        isfile(path) || continue
        title = page_title(path, label)
        push!(entries, (title, "$SITE/$(replace(file, ".md" => ""))/", path))
    end

    open(joinpath(build_dir, "llms.txt"), "w") do io
        println(io, "# JuliaupDistributions.jl\n")
        println(io, "> ", strip(SUMMARY), "\n")
        println(io, "## Documentation\n")
        for (title, url, _) in entries
            println(io, "- [$title]($url)")
        end
    end

    open(joinpath(build_dir, "llms-full.txt"), "w") do io
        println(io, "# JuliaupDistributions.jl\n")
        println(io, "> ", strip(SUMMARY), "\n")
        for (title, url, path) in entries
            println(io, "\n\n---\n")
            println(io, "# $title\n")
            println(io, "Source: $url\n")
            println(io, read(path, String))
        end
    end

    return
end
