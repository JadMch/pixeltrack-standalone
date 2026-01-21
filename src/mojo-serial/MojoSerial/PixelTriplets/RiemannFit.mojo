import math
from sys import is_defined

import choleskyInversion
from FitUtils import Rfit
from MojoSerial.MojoBridge.Matrix import Matrix
from MojoSerial.MojoBridge.SymmetricEigen import (
    min_eigen_2x2,
    min_eigen_3x3,
    min_eigen_3x3_fast,
)


fn computeRadLenUniformMaterial[
    VNd1: AnyType,
    VNd2: AnyType,
](length_values: VNd1, mut rad_lengths:  VNd2):
    comptime XX_0_inv: Float64 = 0.06 / 16.0
    let n = length_values.rows()
    rad_lengths[0] = length_values[0] * XX_0_inv
    var j: Int = 1
    while j < n:
        rad_lengths[j] = abs(length_values[j] - length_values[j - 1]) * XX_0_inv
        j += 1


fn Scatter_cov_line[
    V4: AnyType,
    VNd1: AnyType,
    VNd2: AnyType,
    N: Int,
](
    cov_sz: UnsafePointer[Rfit.Matrix2d],
    fast_fit: V4,
    s_arcs: VNd1,
    z_values: VNd2,
    theta: Float64,
    B: Float64,
    ret: inout Rfit.MatrixNd[N],
):

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=s_arcs), "Scatter_cov_line - s_arcs: ")

    comptime n: Int = N
    var p_t = min(20.0, fast_fit[2] * B)
    var p_2 = p_t * p_t * (1.0 + 1.0 / (fast_fit[3] * fast_fit[3]))

    var rad_lengths_S = Rfit.VectorNd[N]()
    var S_values = Rfit.VectorNd[N]()

    i = 0
    while i < n:
        S_values[i] = math.sqrt(S_values[i])
        i += 1
    computeRadLenUniformMaterial(S_values, rad_lengths_S)
    var sig2_S = Rfit.VectorNd[N]()
    
    i = 0
    while i < n:
        let tmp = 1.0 + 0.038 * math.log(rad_lengths_S[i])
        sig2_S[i] = 0.000225 / p_2 * (tmp * tmp) * rad_lengths_S[i]
        i += 1

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](cov_sz, "Scatter_cov_line - cov_sz: ")



    var tmp = Rfit.Matrix2Nd[N].Zero()

    for k in range(n):
        tmp[k, k] = cov_sz[k][0, 0]
        tmp[k + n, k + n] = cov_sz[k][1, 1]
        tmp[k, k + n] = cov_sz[k][0, 1]
        tmp[k + n, k] = cov_sz[k][0, 1]

    var i = 0
    while i < n:
        let s_val = s_arcs[i]
        let z_val = z_values[i]
        S_values[i] = s_val * s_val + z_val * z_val
        i += 1

    for k in range(n):
        for l in range(k, n):
            for i in range(min(k, l)):
                tmp[k + n, l + n] += abs(S_values[k] - S_values[i]) * abs(S_values[l] - S_values[i]) * sig2_S[i]
            tmp[l + n, k + n] = tmp[k + n, l + n]


    

    






    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=tmp), "Scatter_cov_line - tmp: ")

    for i in range(n):
        for j in range(n):
            ret[i, j] = tmp[i + n, j + n]


fn Scatter_cov_rad[
    M2xN: AnyType,
    V4: AnyType,
    N: Int,
](
    p2D: M2xN,
    fast_fit: V4,
    rad: Rfit.VectorNd[N],
    B: Float64,
) -> Rfit.MatrixNd[N]:
    comptime n: UInt32 = N
    var p_t = min(20.0, fast_fit[2] * B)
    var p_2 = p_t * p_t * (1.0 + 1.0 / (fast_fit[3] * fast_fit[3]))
    var theta = math.atan(fast_fit[3])
    if theta < 0.0:
        theta += math.pi

    var s_values = Rfit.VectorNd[N]()
    var rad_lengths = Rfit.VectorNd[N]()
    var o = Rfit.Vector2d()
    o[0] = fast_fit[0]
    o[1] = fast_fit[1]

    for i in range(n):
        let px = p2D[0, i] - o[0]
        let py = p2D[1, i] - o[1]
        var p = Rfit.Vector2d()
        p[0] = px
        p[1] = py
        var o_neg = Rfit.Vector2d()
        o_neg[0] = -o[0]
        o_neg[1] = -o[1]
        let cross: Float64 = Rfit.cross2D(o_neg, p)
        let dot: Float64 = o_neg[0] * p[0] + o_neg[1] * p[1]
        let atan2_: Float64 = math.atan2(cross, dot)
        s_values[i] = abs(atan2_ * fast_fit[2])

    let scale = math.sqrt(1.0 + 1.0 / (fast_fit[3] * fast_fit[3]))
    var scaled_s_values = Rfit.VectorNd[N]()
    for i in range(n):
        scaled_s_values[i] = s_values[i] * scale

    computeRadLenUniformMaterial(scaled_s_values, rad_lengths)

    var scatter_cov_rad = Rfit.MatrixNd[N].Zero()
    var sig2 = Rfit.VectorNd[N]()
    let sin_theta = math.sin(theta)
    let inv_factor = 0.000225 / (p_2 * Rfit.sqr(sin_theta))
    for i in range(n):
        let tmp = 1.0 + 0.038 * math.log(rad_lengths[i])
        sig2[i] = (tmp * tmp) * rad_lengths[i] * inv_factor

    for k in range(n):
        for l in range(k, n):
            for i in range(min(k, l)):
                scatter_cov_rad[k, l] += (rad[k] - rad[i]) * (rad[l] - rad[i]) * sig2[i]
            scatter_cov_rad[l, k] = scatter_cov_rad[k, l]

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=scatter_cov_rad), "Scatter_cov_rad - scatter_cov_rad: ")

    return scatter_cov_rad


fn cov_radtocart[
    M2xN: AnyType,
    N: Int,
](
    p2D: M2xN,
    cov_rad: Rfit.MatrixNd[N],
    rad: Rfit.VectorNd[N],
) -> Rfit.Matrix2Nd[N]:
    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("Address of p2D: ", UnsafePointer(to=p2D))

    comptime n: Int = N
    var cov_cart = Rfit.Matrix2Nd[N].Zero()
    var rad_inv = Rfit.VectorNd[N]()
    for i in range(n):
        rad_inv[i] = 1.0 / rad[i]

    #####
    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=p2D), "cov_radtocart - p2D:")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=rad_inv), "cov_radtocart - rad_inv:")



    for i in range(n):
        for j in range(i, n):
            cov_cart[i, j] = cov_rad[i, j] * p2D[1, i] * rad_inv[i] * p2D[1, j] * rad_inv[j]
            cov_cart[i + n, j + n] = cov_rad[i, j] * p2D[0, i] * rad_inv[i] * p2D[0, j] * rad_inv[j]
            cov_cart[i, j + n] = -cov_rad[i, j] * p2D[1, i] * rad_inv[i] * p2D[0, j] * rad_inv[j]
            cov_cart[i + n, j] = -cov_rad[i, j] * p2D[0, i] * rad_inv[i] * p2D[1, j] * rad_inv[j]
            cov_cart[j, i] = cov_cart[i, j]
            cov_cart[j + n, i + n] = cov_cart[i + n, j + n]
            cov_cart[j + n, i] = cov_cart[i, j + n]
            cov_cart[j, i + n] = cov_cart[i + n, j]

    return cov_cart


fn cov_carttorad[
    M2xN: AnyType,
    N: Int,
](
    p2D: M2xN,
    cov_cart: Rfit.Matrix2Nd[N],
    rad: Rfit.VectorNd[N],
) -> Rfit.VectorNd[N]:
    comptime n: UInt32 = N
    var cov_rad = Rfit.VectorNd[N]()
    var rad_inv2 = Rfit.VectorNd[N]()
    for i in range(n):
        let inv = 1.0 / rad[i]
        rad_inv2[i] = inv * inv

    for i in range(n):
        if rad[i] < 1.0e-4:
            cov_rad[i] = cov_cart[i, i]
        else:
            cov_rad[i] = rad_inv2[i] * (
                cov_cart[i, i] * Rfit.sqr(p2D[1, i])
                + cov_cart[i + n, i + n] * Rfit.sqr(p2D[0, i])
                - 2.0 * cov_cart[i, i + n] * p2D[0, i] * p2D[1, i]
            )

    return cov_rad


fn cov_carttorad_prefit[
    M2xN: AnyType,
    V4: AnyType,
    N: Int,
](
    p2D: M2xN,
    cov_cart: Rfit.Matrix2Nd[N],
    fast_fit: V4,
    rad: Rfit.VectorNd[N],
) -> Rfit.VectorNd[N]:
    comptime n: UInt32 = N
    var cov_rad = Rfit.VectorNd[N]()
    for i in range(n):
        if rad[i] < 1.0e-4:
            cov_rad[i] = cov_cart[i, i]
        else:
            let ax = p2D[0, i]
            let ay = p2D[1, i]
            let bx = p2D[0, i] - fast_fit[0]
            let by = p2D[1, i] - fast_fit[1]
            let x2 = ax * bx + ay * by
            var a = Rfit.Vector2d()
            a[0] = ax
            a[1] = ay
            var b = Rfit.Vector2d()
            b[0] = bx
            b[1] = by
            let y2 = Rfit.cross2D(a, b)
            let tan_c = -y2 / x2
            let tan_c2 = Rfit.sqr(tan_c)
            cov_rad[i] = 1.0 / (1.0 + tan_c2) * (
                cov_cart[i, i]
                + cov_cart[i + n, i + n] * tan_c2
                + 2.0 * cov_cart[i, i + n] * tan_c
            )

    return cov_rad


fn Weight_circle[
    N: Int,
](cov_rad_inv: Rfit.MatrixNd[N]) -> Rfit.VectorNd[N]:
    let n: Int = N
    var weight = Rfit.VectorNd[N]()
    for j in range(n):
        var sum: Float64 = 0.0
        for i in range(n):
            sum += cov_rad_inv[i, j]
        weight[j] = sum
    return weight


fn Charge[
    M2xN: AnyType,
](p2D: M2xN, par_uvr: Rfit.Vector3d) -> Int32:
    let val = (
        (p2D[0, 1] - p2D[0, 0]) * (par_uvr[1] - p2D[1, 0])
        - (p2D[1, 1] - p2D[1, 0]) * (par_uvr[0] - p2D[0, 0])
    )
    return -1 if val > 0.0 else 1


fn min_eigen3D(
    A: Rfit.Matrix3d,
    chi2: inout Float64,
) -> Rfit.Vector3d:
    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("min_eigen3D - enter")

    let v = min_eigen_3x3(A, chi2)

    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("min_eigen3D - exit")

    return v


fn min_eigen3D_fast(
    A: Rfit.Matrix3d,
) -> Rfit.Vector3d:
    return min_eigen_3x3_fast(A)


fn min_eigen2D(
    A: Rfit.Matrix2d,
    chi2: inout Float64,
) -> Rfit.Vector2d:
    return min_eigen_2x2(A, chi2)


fn Fast_fit[
    M3xN: AnyType,
    V4: AnyType,
](hits: M3xN, result: inout V4):
    let n = M3xN.ColsAtCompileTime()

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=hits), "Fast_fit - hits: ")

    let mid = n // 2
    let b0 = hits[0, mid] - hits[0, 0]
    let b1 = hits[1, mid] - hits[1, 0]
    let c0 = hits[0, n - 1] - hits[0, 0]
    let c1 = hits[1, n - 1] - hits[1, 0]

    let b2 = b0 * b0 + b1 * b1
    let c2 = c0 * c0 + c1 * c1

    var b = Rfit.Vector2d()
    b[0] = b0
    b[1] = b1
    var c = Rfit.Vector2d()
    c[0] = c0
    c[1] = c1

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=b), "Fast_fit - b: ")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=c), "Fast_fit - c: ")

    let flip = abs(b0) < abs(b1)
    let bx = b1 if flip else b0
    let by = b0 if flip else b1
    let cx = c1 if flip else c0
    let cy = c0 if flip else c1

    let div = 2.0 * (cx * by - bx * cy)
    let Y0 = (cx * b2 - bx * c2) / div
    let X0 = (0.5 * b2 - Y0 * by) / bx

    result[0] = hits[0, 0] + (Y0 if flip else X0)
    result[1] = hits[1, 0] + (X0 if flip else Y0)
    result[2] = math.sqrt(Rfit.sqr(X0) + Rfit.sqr(Y0))

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=result), "Fast_fit - result: ")

    let d0 = hits[0, 0] - result[0]
    let d1 = hits[1, 0] - result[1]
    let e0 = hits[0, n - 1] - result[0]
    let e1 = hits[1, n - 1] - result[1]

    var d = Rfit.Vector2d()
    d[0] = d0
    d[1] = d1
    var e = Rfit.Vector2d()
    e[0] = e0
    e[1] = e1

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=e), "Fast_fit - e: ")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=d), "Fast_fit - d: ")

    let cross = Rfit.cross2D(d, e)
    let dot = d0 * e0 + d1 * e1
    let dr = result[2] * math.atan2(cross, dot)
    let dz = hits[2, n - 1] - hits[2, 0]

    result[3] = dr / dz

    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("Fast_fit: [", result[0], ", ", result[1], ", ", result[2], ", ", result[3], "]")


fn Circle_fit[
    M2xN: AnyType,
    V4: AnyType,
    N: Int,
](
    hits2D: M2xN,
    hits_cov2D: Rfit.Matrix2Nd[N],
    fast_fit: V4,
    rad: Rfit.VectorNd[N],
    B: Float64,
    error: Bool,
) -> Rfit.circle_fit:
    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("circle_fit - enter")

    var V: Rfit.Matrix2Nd[N]= hits_cov2D
    comptime n: UInt32 = N

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=hits2D), "circle_fit - hits2D:")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=hits_cov2D), "circle_fit - hits_cov2D:")

    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("circle_fit - WEIGHT COMPUTATION")

    var weight = Rfit.VectorNd[N]()
    var G = Rfit.MatrixNd[N]()
    var renorm: Float64 = 0.0


    {
        let cov_rad_vec = cov_carttorad_prefit[M2xN, V4, N](hits2D, V, fast_fit, rad)
        var cov_rad = Rfit.MatrixNd[N].Zero()
        for i in range(n):
            cov_rad[i, i] = cov_rad_vec[i]

        let scatter_cov_rad = Scatter_cov_rad[M2xN, V4, N](hits2D, fast_fit, rad, B)

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=scatter_cov_rad), "circle_fit - scatter_cov_rad:")
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=hits2D), "circle_fit - hits2D bis:")
            print("Address of hits2D: a) ", UnsafePointer(to=hits2D))

        V += cov_radtocart[M2xN, N](hits2D, scatter_cov_rad, rad)

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=V), "circle_fit - V:")

        cov_rad += scatter_cov_rad

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=cov_rad), "circle_fit - cov_rad:")

        choleskyInversion.invert(cov_rad, G)
        renorm = Float64(G.reduce_add())
        let scale = 1.0 / renorm
        for i in range(n):
            for j in range(n):
                G[i, j] *= scale
        weight = Weight_circle[N](G)
    }

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=weight), "circle_fit - weight:")
        print("circle_fit - SPACE TRANSFORMATION")
        print("Address of hits2D: b) ", UnsafePointer(to=hits2D))

    var h_ = Rfit.Vector2d()
    var sum0: Float64 = 0.0
    var sum1: Float64 = 0.0
    for i in range(n):
        sum0 += hits2D[0, i]
        sum1 += hits2D[1, i]
    h_[0] = sum0 / Float64(n)
    h_[1] = sum1 / Float64(n)

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=h_), "circle_fit - h_:")

    var p3D = Rfit.Matrix3xNd[N]()
    for i in range(n):
        p3D[0, i] = hits2D[0, i] - h_[0]
        p3D[1, i] = hits2D[1, i] - h_[1]

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=p3D), "circle_fit - p3D: a)")

    var mc = Rfit.Vector2Nd[N]()
    for i in range(n):
        mc[i] = p3D[0, i]
        mc[i + n] = p3D[1, i]

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=mc), "circle_fit - mc(centered hits):")

    var q: Float64 = 0.0
    for i in range(2 * n):
        q += mc[i] * mc[i]

    let s = math.sqrt(Float64(n) / q)
    for i in range(3):
        for j in range(n):
            p3D[i, j] *= s

    for i in range(n):
        p3D[2, i] = p3D[0, i] * p3D[0, i] + p3D[1, i] * p3D[1, i]

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=p3D), "circle_fit - p3D: b)")
        print("circle_fit - COST FUNCTION")

    var r0 = Rfit.Vector3d()
    for i in range(3):
        var sum: Float64 = 0.0
        for j in range(n):
            sum += p3D[i, j] * weight[j]
        r0[i] = sum

    var X = Rfit.Matrix3xNd[N]()
    for j in range(n):
        for i in range(3):
            X[i, j] = p3D[i, j] - r0[i]

    let A = (X @ G) @ X.transpose()

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=A), "circle_fit - A:")
        print("circle_fit - MINIMIZE")

    var chi2: Float64 = 0.0
    var v = min_eigen3D(A, chi2)

    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("circle_fit - AFTER MIN_EIGEN")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=v), "v BEFORE INVERSION")

    if v[2] <= 0.0:
        v[0] = -v[0]
        v[1] = -v[1]
        v[2] = -v[2]

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=v), "v AFTER INVERSION")

    # This hack to be able to run on GPU where the automatic assignment to a
    # double from the vector multiplication is not working.
    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("circle_fit - AFTER MIN_EIGEN 1")

    var cm = Matrix[Float64, 1, 1]()

    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("circle_fit - AFTER MIN_EIGEN 2")

    cm = -(v.transpose() @ r0)

    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("circle_fit - AFTER MIN_EIGEN 3")

    let c = cm[0, 0]

    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("circle_fit - COMPUTE CIRCLE PARAMETER")

    let h = math.sqrt(1.0 - Rfit.sqr(v[2]) - 4.0 * c * v[2])
    let v2x2_inv = 1.0 / (2.0 * v[2])
    let s_inv = 1.0 / s

    var par_uvr_ = Rfit.Vector3d()
    par_uvr_[0] = -v[0] * v2x2_inv
    par_uvr_[1] = -v[1] * v2x2_inv
    par_uvr_[2] = h * v2x2_inv

    var circle = Rfit.circle_fit()
    circle.par[0] = par_uvr_[0] * s_inv + h_[0]
    circle.par[1] = par_uvr_[1] * s_inv + h_[1]
    circle.par[2] = par_uvr_[2] * s_inv
    circle.q = Charge(hits2D, circle.par)
    circle.chi2 = abs(chi2) * renorm * 1.0 / Rfit.sqr(2.0 * v[2] * par_uvr_[2] * s)

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=circle.par), "circle_fit - CIRCLE PARAMETERS:")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=circle.cov), "circle_fit - CIRCLE COVARIANCE:")
        print("circle_fit - CIRCLE CHARGE: ", circle.q)
        print("circle_fit - ERROR PROPAGATION")

    if error:
        @parameter
        if is_defined["RFIT_DEBUG"]():
            print("circle_fit - ERROR PRPAGATION ACTIVATED")

        var Vcs_ = InlineArray[InlineArray[Rfit.ArrayNd[N], 2], 2]()
        var C = InlineArray[InlineArray[Rfit.MatrixNd[N], 3], 3]()

        @parameter
        if is_defined["RFIT_DEBUG"]():
            print("circle_fit - ERROR PRPAGATION ACTIVATED 2")

        {
            var cm = Matrix[Float64, 1, 1]()
            var cm2 = Matrix[Float64, 1, 1]()
            cm = (mc.transpose() @ V) @ mc
            let c = cm[0, 0]

            var Vcs = Rfit.Matrix2Nd[N].Zero()
            var V_sq_norm: Float64 = 0.0
            for i in range(2 * n):
                for j in range(2 * n):
                    V_sq_norm += V[i, j] * V[i, j]

            let scale = (Rfit.sqr(s) * Rfit.sqr(s)) * (2.0 * V_sq_norm + 4.0 * c) / (4.0 * q * Float64(n))
            for i in range(2 * n):
                for j in range(2 * n):
                    Vcs[i, j] = Rfit.sqr(s) * V[i, j] + scale * mc[i] * mc[j]

            @parameter
            if is_defined["RFIT_DEBUG"]():
                Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=Vcs), "circle_fit - Vcs:")

            for i in range(n):
                for j in range(n):
                    C[0][0][i, j] = Vcs[i, j]
                    Vcs_[0][1][i, j] = Vcs[i, j + n]
                    C[1][1][i, j] = Vcs[i + n, j + n]
            for i in range(n):
                for j in range(n):
                    Vcs_[1][0][i, j] = Vcs_[0][1][j, i]

            @parameter
            if is_defined["RFIT_DEBUG"]():
                Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=Vcs), "circle_fit - Vcs:")
        }

        {
            var t0 = Rfit.ArrayNd[N]()
            var t1 = Rfit.ArrayNd[N]()
            var t00 = Rfit.ArrayNd[N]()
            var t01 = Rfit.ArrayNd[N]()
            var t11 = Rfit.ArrayNd[N]()
            var t10 = Rfit.ArrayNd[N]()

            for i in range(n):
                for j in range(n):
                    t0[i, j] = p3D[0, j]
                    t1[i, j] = p3D[1, j]
                    t00[i, j] = p3D[0, i] * p3D[0, j]
                    t01[i, j] = p3D[0, i] * p3D[1, j]
                    t11[i, j] = p3D[1, i] * p3D[1, j]
                    t10[i, j] = t01[j, i]

            for i in range(n):
                for j in range(n):
                    Vcs_[0][0][i, j] = C[0][0][i, j]
                    C[0][1][i, j] = Vcs_[0][1][i, j]
                    C[0][2][i, j] = 2.0 * (Vcs_[0][0][i, j] * t0[i, j] + Vcs_[0][1][i, j] * t1[i, j])
                    Vcs_[1][1][i, j] = C[1][1][i, j]
                    C[1][2][i, j] = 2.0 * (Vcs_[1][0][i, j] * t0[i, j] + Vcs_[1][1][i, j] * t1[i, j])

            var tmp = Rfit.MatrixNd[N]()
            for i in range(n):
                for j in range(n):
                    let term1 = (
                        Vcs_[0][0][i, j] * Vcs_[0][0][i, j]
                        + Vcs_[0][0][i, j] * Vcs_[0][1][i, j]
                        + Vcs_[1][1][i, j] * Vcs_[1][0][i, j]
                        + Vcs_[1][1][i, j] * Vcs_[1][1][i, j]
                    )
                    let term2 = (
                        Vcs_[0][0][i, j] * t00[i, j]
                        + Vcs_[0][1][i, j] * t01[i, j]
                        + Vcs_[1][0][i, j] * t10[i, j]
                        + Vcs_[1][1][i, j] * t11[i, j]
                    )
                    tmp[i, j] = 2.0 * term1 + 4.0 * term2
            C[2][2] = tmp
        }

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=C[0][0]), "circle_fit - C[0][0]:")

        var C0 = Rfit.Matrix3d()
        for i in range(3):
            for j in range(i, 3):
                var sum: Float64 = 0.0
                for a in range(n):
                    for b in range(n):
                        sum += weight[a] * C[i][j][a, b] * weight[b]
                C0[i, j] = sum
                C0[j, i] = sum

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=C0), "circle_fit - C0:")

        var W = Rfit.MatrixNd[N]()
        for i in range(n):
            for j in range(n):
                W[i, j] = weight[i] * weight[j]

        var H = Rfit.MatrixNd[N].identity()
        for i in range(n):
            for j in range(n):
                H[i, j] -= weight[j]

        let s_v = H @ p3D.transpose()

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=W), "circle_fit - W:")
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=H), "circle_fit - H:")
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=s_v), "circle_fit - s_v:")

        var D_ = InlineArray[InlineArray[Rfit.MatrixNd[N], 3], 3]()
        {
            let tmp00 = (H @ C[0][0]) @ H.transpose()
            let tmp01 = (H @ C[0][1]) @ H.transpose()
            let tmp02 = (H @ C[0][2]) @ H.transpose()
            let tmp11 = (H @ C[1][1]) @ H.transpose()
            let tmp12 = (H @ C[1][2]) @ H.transpose()
            let tmp22 = (H @ C[2][2]) @ H.transpose()

            for i in range(n):
                for j in range(n):
                    D_[0][0][i, j] = tmp00[i, j] * W[i, j]
                    D_[0][1][i, j] = tmp01[i, j] * W[i, j]
                    D_[0][2][i, j] = tmp02[i, j] * W[i, j]
                    D_[1][1][i, j] = tmp11[i, j] * W[i, j]
                    D_[1][2][i, j] = tmp12[i, j] * W[i, j]
                    D_[2][2][i, j] = tmp22[i, j] * W[i, j]

            D_[1][0] = D_[0][1].transpose()
            D_[2][0] = D_[0][2].transpose()
            D_[2][1] = D_[1][2].transpose()
        }

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=D_[0][0]), "circle_fit - D_[0][0]:")

        comptime nu = InlineArray[InlineArray[UInt32, 2], 6](
            InlineArray[UInt32, 2](0, 0),
            InlineArray[UInt32, 2](0, 1),
            InlineArray[UInt32, 2](0, 2),
            InlineArray[UInt32, 2](1, 1),
            InlineArray[UInt32, 2](1, 2),
            InlineArray[UInt32, 2](2, 2),
        )

        var E = Rfit.Matrix6d()
        for a in range(6):
            let i = nu[a][0].cast[Int]()
            let j = nu[a][1].cast[Int]()
            for b in range(a, 6):
                let k = nu[b][0].cast[Int]()
                let l = nu[b][1].cast[Int]()

                var t0 = Rfit.VectorNd[N]()
                var t1 = Rfit.VectorNd[N]()

                if l == k:
                    for idx in range(n):
                        var sum0: Float64 = 0.0
                        for m in range(n):
                            sum0 += D_[j][l][idx, m] * s_v[m, l]
                        t0[idx] = 2.0 * sum0
                    if i == j:
                        t1 = t0
                    else:
                        for idx in range(n):
                            var sum1: Float64 = 0.0
                            for m in range(n):
                                sum1 += D_[i][l][idx, m] * s_v[m, l]
                            t1[idx] = 2.0 * sum1
                else:
                    for idx in range(n):
                        var sum0: Float64 = 0.0
                        for m in range(n):
                            sum0 += (
                                D_[j][l][idx, m] * s_v[m, k]
                                + D_[j][k][idx, m] * s_v[m, l]
                            )
                        t0[idx] = sum0
                    if i == j:
                        t1 = t0
                    else:
                        for idx in range(n):
                            var sum1: Float64 = 0.0
                            for m in range(n):
                                sum1 += (
                                    D_[i][l][idx, m] * s_v[m, k]
                                    + D_[i][k][idx, m] * s_v[m, l]
                                )
                            t1[idx] = sum1

                var cm: Float64 = 0.0
                if i == j:
                    for idx in range(n):
                        cm += s_v[idx, i] * (t0[idx] + t1[idx])
                else:
                    for idx in range(n):
                        cm += s_v[idx, i] * t0[idx] + s_v[idx, j] * t1[idx]

                E[a, b] = cm
                if b != a:
                    E[b, a] = E[a, b]

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=E), "circle_fit - E:")

        var J2 = Matrix[Float64, 3, 6]()
        for a in range(6):
            let i : UInt32= nu[a][0].cast[UInt32]()
            let j : UInt32= nu[a][1].cast[UInt32]()
            var Delta = Rfit.Matrix3d.Zero()
            let delta_val = abs(A[i, j] * Rfit.d)
            Delta[i, j] = delta_val
            Delta[j, i] = delta_val

            var J2_col = min_eigen3D_fast(A + Delta)
            let sign = 1.0 if J2_col[2] > 0.0 else -1.0
            for r in range(3):
                J2_col[r] = (J2_col[r] * sign - v[r]) / delta_val
            for r in range(3):
                J2[r, a] = J2_col[r]

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=J2), "circle_fit - J2:")

        var Cvc = Rfit.Matrix4d()
        {
            let t0 = (J2 @ E) @ J2.transpose()
            var t1 = Rfit.Vector3d()
            for r in range(3):
                t1[r] = -(t0[r, 0] * r0[0] + t0[r, 1] * r0[1] + t0[r, 2] * r0[2])

            for r in range(3):
                for c in range(3):
                    Cvc[r, c] = t0[r, c]
                Cvc[r, 3] = t1[r]
                Cvc[3, r] = t1[r]

            var cm1: Float64 = 0.0
            var cm3: Float64 = 0.0
            var cm_sum: Float64 = 0.0
            for i in range(3):
                var row_sum: Float64 = 0.0
                var row_sum_r0: Float64 = 0.0
                for j in range(3):
                    row_sum += C0[i, j] * v[j]
                    cm_sum += C0[i, j] * t0[i, j]
                    row_sum_r0 += t0[i, j] * r0[j]
                cm1 += v[i] * row_sum
                cm3 += r0[i] * row_sum_r0

            Cvc[3, 3] = cm1 + cm_sum + cm3
        }

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=Cvc), "circle_fit - Cvc:")

        var J3 = Matrix[Float64, 3, 4]()
        {
            let t: Float64= 1.0 / h
            J3[0, 0] = -v2x2_inv
            J3[0, 1] = 0.0
            J3[0, 2] = v[0] * Rfit.sqr(v2x2_inv) * 2.0
            J3[0, 3] = 0.0
            J3[1, 0] = 0.0
            J3[1, 1] = -v2x2_inv
            J3[1, 2] = v[1] * Rfit.sqr(v2x2_inv) * 2.0
            J3[1, 3] = 0.0
            J3[2, 0] = v[0] * v2x2_inv * t
            J3[2, 1] = v[1] * v2x2_inv * t
            J3[2, 2] = -h * Rfit.sqr(v2x2_inv) * 2.0 - (2.0 * c + v[2]) * v2x2_inv * t
            J3[2, 3] = -t
        }

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=J3), "circle_fit - J3:")

        var Jq = Rfit.RowVector2Nd[N]()
        for i in range(2 * n):
            Jq[0, i] = mc[i] * s / Float64(n)

        @parameter
        if is_defined["RFIT_DEBUG"]():
            Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=Jq), "circle_fit - Jq:")

        var cov_uvr = (J3 @ Cvc) @ J3.transpose()
        let scale = Rfit.sqr(s_inv)
        for i in range(3):
            for j in range(3):
                cov_uvr[i, j] *= scale


        # Maybe optimise if V is a covariance matrix 
        var scalar: Float64 = 0.0
        for i in range(2 * n):
            for j in range(2 * n):
                scalar += Jq[0, i] * V[i, j] * Jq[0, j]


        for i in range(3):
            for j in range(3):
                cov_uvr[i, j] += par_uvr_[i] * par_uvr_[j] * scalar

        circle.cov = cov_uvr

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=circle.cov), "Circle cov:")
        print("circle_fit - exit")

    return circle


fn Line_fit[
    M3xN: AnyType,
    M6xN: AnyType,
    V4: AnyType,
](
    hits: M3xN,
    hits_ge: M6xN,
    circle: Rfit.circle_fit,
    fast_fit: V4,
    B: Float64,
    error: Bool,
) -> Rfit.line_fit:
    comptime N: Int = M3xN.ColsAtCompileTime()
    comptime n: Int = N
    var theta = -Float64(circle.q) * math.atan(fast_fit[3])
    if theta < 0.0:
        theta += math.pi

    var rot = Rfit.Matrix2d()
    rot[0, 0] = math.sin(theta)
    rot[0, 1] = math.cos(theta)
    rot[1, 0] = -math.cos(theta)
    rot[1, 1] = math.sin(theta)

    var p2D = Rfit.Matrix2xNd[N].Zero()
    var Jx = Matrix[Float64, 2, 6]()

    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("Line_fit - B: ", B)
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=hits), "Line_fit points: ")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=hits_ge), "Line_fit covs: ")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=rot), "Line_fit rot: ")

    let ox = circle.par[0]
    let oy = circle.par[1]

    var Cov = Rfit.Matrix6d.Zero()
    var cov_sz = InlineArray[Rfit.Matrix2d, N]()

    for i in range(n):
        let px = hits[0, i] - ox
        let py = hits[1, i] - oy
        var p = Rfit.Vector2d()
        p[0] = px
        p[1] = py
        var o_neg = Rfit.Vector2d()
        o_neg[0] = -ox
        o_neg[1] = -oy
        let cross :Float64 = Rfit.cross2D(o_neg, p)
        let dot : Float64 = o_neg[0] * p[0] + o_neg[1] * p[1]
        let atan2_ : float64= -Float64(circle.q) * math.atan2(cross, dot)
        p2D[0, i] = atan2_ * circle.par[2]

        let temp0 :Float64 = -Float64(circle.q) * circle.par[2] * 1.0 / (Rfit.sqr(dot) + Rfit.sqr(cross))
        var d_X0 : Float64= 0.0
        var d_Y0 : Float64= 0.0
        var d_R =: Float64 0.0
        if error:
            d_X0 = -temp0 * ((py + oy) * dot - (px - ox) * cross)
            d_Y0 = temp0 * ((px + ox) * dot - (oy - py) * cross)
            d_R = atan2_
        let d_x : Float64 = temp0 * (oy * dot + ox * cross)
        let d_y : Float64 = temp0 * (-ox * dot + oy * cross)

        Jx[0, 0] = d_X0
        Jx[0, 1] = d_Y0
        Jx[0, 2] = d_R
        Jx[0, 3] = d_x
        Jx[0, 4] = d_y
        Jx[0, 5] = 0.0
        Jx[1, 0] = 0.0
        Jx[1, 1] = 0.0
        Jx[1, 2] = 0.0
        Jx[1, 3] = 0.0
        Jx[1, 4] = 0.0
        Jx[1, 5] = 1.0

        for r in range(3):
            for c in range(3):
                Cov[r, c] = circle.cov[r, c]

        Cov[3, 3] = hits_ge[0, i]
        Cov[4, 4] = hits_ge[2, i]
        Cov[5, 5] = hits_ge[5, i]
        Cov[3, 4] = hits_ge[1, i]
        Cov[4, 3] = hits_ge[1, i]
        Cov[3, 5] = hits_ge[3, i]
        Cov[5, 3] = hits_ge[3, i]
        Cov[4, 5] = hits_ge[4, i]
        Cov[5, 4] = hits_ge[4, i]

        let tmp : Matrix2d= (Jx @ Cov) @ Jx.transpose()
        cov_sz[i] = (rot @ tmp) @ rot.transpose()

    for i in range(n):
        p2D[1, i] = hits[2, i]

    var s_arcs = Rfit.VectorNd[N]()
    var z_values = Rfit.VectorNd[N]()
    for i in range(n):
        s_arcs[i] = p2D[0, i]
        z_values[i] = p2D[1, i]

    var cov_with_ms = Rfit.MatrixNd[N]()
    Scatter_cov_line(
        cov_sz.unsafe_ptr().as_noalias_ptr(),
        fast_fit,
        s_arcs,
        z_values,
        theta,
        B,
        cov_with_ms,
    )

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](cov_sz.unsafe_ptr(), "line_fit - cov_sz:")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=cov_with_ms), "line_fit - cov_with_ms: ")

    let p2D_rot : Rfit.Matrix2xNd[N]= rot @ p2D

    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("Fast fit Tan(theta): ", fast_fit[3])
        print("Rotation angle: ", theta)
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=rot), "Rotation Matrix:")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=p2D), "Original Hits(s,z):")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=p2D_rot), "Rotated hits(S3D, Z'):")

    var p2D_rot_row1 = Rfit.VectorNd[N]()
    for i in range(n):
        p2D_rot_row1[i] = p2D_rot[1, i]

    var A = Rfit.Matrix2xNd[N]()
    for i in range(n):
        A[0, i] = 1.0
        A[1, i] = p2D_rot[0, i]

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=A), "A Matrix:")

    var Vy_inv = Rfit.MatrixNd[N]()
    choleskyInversion.invert(cov_with_ms, Vy_inv)

    var Cov_params: Rfit.Matrix2d = (A @ Vy_inv) @ A.transpose()
    choleskyInversion.invert(Cov_params, Cov_params)

    var sol = (Cov_params @ A) @ (Vy_inv @ p2D_rot_row1)

    @parameter
    if is_defined["RFIT_DEBUG"]():
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=sol), "Rotated solutions:")

    let common_factor = 1.0 / (math.sin(theta) - sol[1, 0] * math.cos(theta))
    var J = Rfit.Matrix2d()
    J[0, 0] = 0.0
    J[0, 1] = common_factor * common_factor
    J[1, 0] = common_factor
    J[1, 1] = sol[0, 0] * math.cos(theta) * common_factor * common_factor

    let m = common_factor * (sol[1, 0] * math.sin(theta) + math.cos(theta))
    let q = common_factor * sol[0, 0]
    let cov_mq = (J @ Cov_params) @ J.transpose()

    let res = p2D_rot_row1 - (A.transpose() @ sol)
    let chi2 = (res.transpose() @ (Vy_inv @ res))[0, 0]

    var line = Rfit.line_fit()
    line.par[0] = m
    line.par[1] = q
    line.cov = cov_mq
    line.chi2 = chi2

    @parameter
    if is_defined["RFIT_DEBUG"]():
        print("Common_factor: ", common_factor)
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=J), "Jacobian:")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=sol), "Rotated solutions:")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=Cov_params), "Cov_params:")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=cov_mq), "Rotated Covariance Matrix:")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=line.par), "Real Parameters:")
        Rfit.printIt[RFIT_DEBUG=True](UnsafePointer(to=line.cov), "Real Covariance Matrix:")
        print("Chi2: ", chi2)

    return line


fn Helix_fit[
    N: Int,
](
    hits: Rfit.Matrix3xNd[N],
    hits_ge: Matrix[Float32, 6, N],
    B: Float64,
    error: Bool,
) -> Rfit.helix_fit:
    let n: Int = N
    var rad = Rfit.VectorNd[N]()
    for i in range(n):
        rad[i] = math.sqrt(hits[0, i] * hits[0, i] + hits[1, i] * hits[1, i])

    var fast_fit = Rfit.Vector4d()
    Fast_fit(hits, fast_fit)

    var hits_cov: Rfit.Matrix2Nd[N] = Rfit.MatrixXd.Zero(2 * n, 2 * n)
    Rfit.loadCovariance2D(hits_ge, hits_cov)

    var hits2D = Rfit.Matrix2xNd[N]()
    for i in range(n):
        hits2D[0, i] = hits[0, i]
        hits2D[1, i] = hits[1, i]

    var circle = Circle_fit(
        hits2D,
        hits_cov,
        fast_fit,
        rad,
        B,
        error,
    )
    let line = Line_fit(
        hits,
        hits_ge,
        circle,
        fast_fit,
        B,
        error,
    )

    Rfit.par_uvrtopak(circle, B, error)

    var helix = Rfit.helix_fit()
    helix.par[0] = circle.par[0]
    helix.par[1] = circle.par[1]
    helix.par[2] = circle.par[2]
    helix.par[3] = line.par[0]
    helix.par[4] = line.par[1]

    if error:
        helix.cov = Rfit.Matrix5d.Zero()
        for i in range(3):
            for j in range(3):
                helix.cov[i, j] = circle.cov[i, j]
        for i in range(2):
            for j in range(2):
                helix.cov[i + 3, j + 3] = line.cov[i, j]

    helix.q = circle.q
    helix.chi2_circle = circle.chi2
    helix.chi2_line = line.chi2

    return helix
