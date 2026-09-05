@testitem "Aqua quality assurance" begin
    using Aqua
    using JuliaupDistributions

    Aqua.test_all(JuliaupDistributions)
end
