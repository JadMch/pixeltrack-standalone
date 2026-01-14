import math

from MojoSerial.MojoBridge.Matrix import Matrix


fn min_eigen_2x2(
    A: Matrix[Float64, 2, 2], chi2: inout Float64
) -> Matrix[Float64, 2, 1]:
    let a = A[0, 0]
    let b = A[0, 1]
    let c = A[1, 1]
    let tr = a + c
    let diff = a - c
    let delta = math.sqrt(diff * diff + 4.0 * b * b)
    let lambda_min = 0.5 * (tr - delta)
    chi2 = lambda_min

    var v0 = b
    var v1 = lambda_min - a
    if abs(v0) < 1.0e-12 and abs(v1) < 1.0e-12:
        if a <= c:
            v0 = 1.0
            v1 = 0.0
        else:
            v0 = 0.0
            v1 = 1.0

    let norm = math.sqrt(v0 * v0 + v1 * v1)
    if norm != 0.0:
        v0 /= norm
        v1 /= norm

    var vec = Matrix[Float64, 2, 1]()
    vec[0, 0] = v0
    vec[1, 0] = v1
    return vec


fn min_eigen_3x3(
    A: Matrix[Float64, 3, 3], chi2: inout Float64
) -> Matrix[Float64, 3, 1]:
    var D = A
    var V = Matrix[Float64, 3, 3].identity()
    var iter = 0
    while iter < 12:
        var p = 0
        var q = 1
        var max_val = abs(D[0, 1])
        if abs(D[0, 2]) > max_val:
            max_val = abs(D[0, 2])
            p = 0
            q = 2
        if abs(D[1, 2]) > max_val:
            max_val = abs(D[1, 2])
            p = 1
            q = 2

        if max_val < 1.0e-12:
            break

        let app = D[p, p]
        let aqq = D[q, q]
        let apq = D[p, q]
        let phi = 0.5 * math.atan2(2.0 * apq, aqq - app)
        let c = math.cos(phi)
        let s = math.sin(phi)

        D[p, p] = c * c * app - 2.0 * s * c * apq + s * s * aqq
        D[q, q] = s * s * app + 2.0 * s * c * apq + c * c * aqq
        D[p, q] = 0.0
        D[q, p] = 0.0

        for i in range(3):
            if i != p and i != q:
                let aip = D[i, p]
                let aiq = D[i, q]
                D[i, p] = c * aip - s * aiq
                D[p, i] = D[i, p]
                D[i, q] = s * aip + c * aiq
                D[q, i] = D[i, q]

        for i in range(3):
            let vip = V[i, p]
            let viq = V[i, q]
            V[i, p] = c * vip - s * viq
            V[i, q] = s * vip + c * viq

        iter += 1

    var min_idx = 0
    var min_val = D[0, 0]
    if D[1, 1] < min_val:
        min_val = D[1, 1]
        min_idx = 1
    if D[2, 2] < min_val:
        min_val = D[2, 2]
        min_idx = 2
    chi2 = min_val

    var vec = Matrix[Float64, 3, 1]()
    vec[0, 0] = V[0, min_idx]
    vec[1, 0] = V[1, min_idx]
    vec[2, 0] = V[2, min_idx]

    let norm = math.sqrt(
        vec[0, 0] * vec[0, 0]
        + vec[1, 0] * vec[1, 0]
        + vec[2, 0] * vec[2, 0]
    )
    if norm != 0.0:
        vec[0, 0] /= norm
        vec[1, 0] /= norm
        vec[2, 0] /= norm
    return vec


fn min_eigen_3x3_fast(
    A: Matrix[Float64, 3, 3]
) -> Matrix[Float64, 3, 1]:
    var chi2: Float64 = 0.0
    return min_eigen_3x3(A, chi2)
