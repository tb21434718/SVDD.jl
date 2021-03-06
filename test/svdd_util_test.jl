
@testset "SVDD_util_test" begin

    @testset "merge pool" begin
        pools = labelmap([:U, :Lin, :Lout, :U, :U, :Lin])

        @test [] == SVDD.merge_pools(pools, [])

        @test [1,4,5] == SVDD.merge_pools(pools, :U)
        @test [1,4,5] == sort(SVDD.merge_pools(pools, :U, :U))
        @test [2,6] == SVDD.merge_pools(pools, :Lin)
        @test [3] == SVDD.merge_pools(pools, :Lout)

        @test [2,3,6] == sort(SVDD.merge_pools(pools, :Lin, :Lout))
        @test collect(1:6) == sort(SVDD.merge_pools(pools, :U, :Lin, :Lout))

        @test_throws ArgumentError SVDD.merge_pools(pools, :A)
    end

    @testset "labelmap2vec" begin
        @testset "Symbol" begin
            labelvec = [:yes,:no,:no,:yes,:yes]
            @test labelvec == labelmap2vec(labelmap(labelvec))
            labelvec = Vector{Symbol}(undef, 0)
            @test labelvec == labelmap2vec(labelmap(labelvec))
        end

        @testset "Float64" begin
            labelvec = [1.,-1,-1,1,1]
            @test labelvec == labelmap2vec(labelmap(labelvec))
            labelvec = Vector{Float64}(undef, 0)
            @test labelvec == labelmap2vec(labelmap(labelvec))
        end
    end

    @testset "classify" begin
        @testset "single space" begin
            scores = [2.0, 0.0, 0.01, -0.1, -5.0]
            expected = [:outlier, :inlier, :outlier, :inlier, :inlier]
            actual = SVDD.classify.(scores)
            @test MLLabelUtils.islabelenc(actual, SVDD.class_label_enc)
            @test expected == actual
        end

        @testset "subspaces" begin
            scores = [[2.0, 0.0, 0.01, -0.1, -5.0],
                      [2.0, 0.0, 0.0, -0.1, 5.0]]
            expected_local = [[:outlier, :inlier, :outlier, :inlier, :inlier],
                              [:outlier, :inlier, :inlier, :inlier, :outlier]]
            expected_global = [:outlier, :inlier, :outlier, :inlier, :outlier]

            actual_local = SVDD.classify(scores, Val(:Subspace))
            actual_global = SVDD.classify(scores, Val(:Global))
            @test expected_local == actual_local
            @test expected_global == actual_global
        end
    end

    @testset "adjust kernel" begin
        K1 = [2 -1 0; -1 2 -1; 0 -1 2]
        K2 = [1 2; 2 1]
        @testset "single space" begin
            @assert all(eigen(K1).values .> 0)
            @test K1 ≈ SVDD.adjust_kernel_matrix(K1)

            @assert any(eigen(K2).values .< 0)
            K2_adjusted = SVDD.adjust_kernel_matrix(K2, warn_threshold = 2)
            @test !(K2 ≈ K2_adjusted)
            @test all(eigen(K2_adjusted).values .>= 0.0)

            Random.seed!(42)
            dummy_data, _ = generate_mvn_with_outliers(2, 100, 42, true, true)
            model = SVDD.VanillaSVDD(dummy_data)
            init_strategy = SVDD.FixedParameterInitialization(MLKernels.GaussianKernel(4), 0.1)
            SVDD.initialize!(model, init_strategy)
            K_old = copy(model.K)
            @assert any(eigen(model.K).values .< 0)

            @test_throws ArgumentError SVDD.adjust_kernel_matrix([3 -2; 4 -1])
        end

        @testset "subspaces" begin
            K = [K1, K2]
            @assert all(eigen(K[1]).values .> 0)
            @assert any(eigen(K[2]).values .< 0)
            K_adjusted = SVDD.adjust_kernel_matrix(K, warn_threshold = 2)
            @test K[1] ≈ K_adjusted[1]
            @test !(K[2] ≈ K_adjusted[2])
            @test all(eigen(K_adjusted[2]).values .>= 0.0)
        end
    end



    @testset "min_max_normalize" begin
        @test min_max_normalize([1,2]) ≈ [0.0, 1.0]
        @test min_max_normalize([-1,2]) ≈ [0.0, 1.0]
        @test isnan(min_max_normalize(1))
        @test isnan(min_max_normalize(-1))
        @test min_max_normalize([0, 20, -20, 0]) ≈ [0.5, 1.0, 0.0, 0.5]
    end
end
