using Documenter
using JuliaupDistributions

include("llms.jl")

const PAGES = [
    "Home" => "index.md",
    "How juliaup works" => "mechanism.md",
    "Publishing" => "publishing.md",
    "Reference" => "reference.md",
]

makedocs(
    sitename = "JuliaupDistributions.jl",
    repo = Documenter.Remotes.GitHub("s-celles", "JuliaupDistributions.jl"),
    format = Documenter.HTML(),
    modules = [JuliaupDistributions],
    checkdocs = :public,
    pages = PAGES,
)

generate_llms_txt(joinpath(@__DIR__, "build"),
                  joinpath(@__DIR__, "src"), PAGES)

deploydocs(repo = "github.com/s-celles/JuliaupDistributions.jl.git",
           push_preview = true)
