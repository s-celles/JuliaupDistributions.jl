# Main entry points for JuliaupDistributions development.

julia := "julia --startup-file=no"

default:
    @just --list

# Install dependencies
instantiate:
    {{julia}} --project=. -e 'using Pkg; Pkg.instantiate()'

# Run the test suite
test:
    {{julia}} --project=. -e 'using Pkg; Pkg.test()'

# Run the end to end test against a real juliaup client
test-e2e:
    {{julia}} --project=. test/e2e_tests.jl

# Build the documentation, including llms.txt and llms-full.txt
docs:
    {{julia}} --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path = pwd())); Pkg.instantiate()'
    {{julia}} --project=docs docs/make.jl

# Remove build outputs
clean:
    rm -rf docs/build
