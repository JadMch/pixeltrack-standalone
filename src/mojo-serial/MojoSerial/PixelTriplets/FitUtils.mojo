from CUDECore import cuda_assert
from CudaCore import cudaCompat

import choleskyInversion
import FitResult

struct Rfit():

    var d : Float64 = .00001

    alias VectorXd = Eigen.VectorXd
    alias MatrixXd = Eigen.MatrixXd
    alias MatrixNd[N : Int] = Eigen.Matrix[Float64 , N , N]
    alias MatrixNplusONEd[N : Int] = Eigen.Matrix[Float64 , N + 1, N + 1]
    alias ArrayNd[N : Int] = Eigen.Array[Float64 , N , N]
    
    alias Matrix2Nd[N : Int]= Eigen.Matrix[Float64, 2 * N, 2 * N]
    
    alias Matrix3Nd[N : Int]= Eigen.Matrix[Float64, 3 * N, 3 * N]
    
    alias Matrix2xNd[N : Int]= Eigen.Matrix[Float64, 2, N]
    
    alias Array2xNd[N : Int]= Eigen.Array[Float64, 2, N]
    
    alias MatrixNx3d[N : Int]= Eigen.Matrix[Float64, N, 3]
    
    alias MatrixNx5d[N : Int]= Eigen.Matrix[Float64, N, 5]
    
    alias VectorNd[N : Int]= Eigen.Matrix[Float64, N, 1]
    
    alias VectorNplusONEd[N : Int]= Eigen.Matrix[Float64, N + 1, 1]
    
    alias Vector2Nd[N : Int]= Eigen.Matrix[Float64, 2 * N, 1]
    
    alias Vector3Nd[N : Int] = Eigen.Matrix[Float64, 3 * N, 1]
    
    alias RowVectorNd[N : Int] = Eigen.Matrix[Float64, 1, 1, N]
    
    alias RowVector2Nd[N : Int] = Eigen.Matrix[Float64, 1, 2 * N]

    alias Matrix2x3d = Eigen.Matrix[Float64, 2, 3]

    alias Matrix3f = Eigen.Matrix3f
    alias Vector3f = Eigen.Vector3f
    alias Vector4f = Eigen.Vector4f

    alias u_int = UInt32

    fn printIt[C: AnyType, RFIT_DEBUG: Bool = False](m: UnsafePointer[C], prefix: StringLiteral = ""):
    @parameter
    if RFIT_DEBUG:
        for r in range(m[].rows()):
            for c in range(m[].cols()):
                print(prefix, "Matrix(", r, ",", c, ") =", m[][r, c])

    #raise to square 
    fn sqr[T : AnyType](T a) -> T:


    #  /*!
    #\brief Compute cross product of two 2D vector (assuming z component 0),
    #returning z component of the result.
    #\param a first 2D vector in the product.
    #\param b second 2D vector in the product.
    #\return z component of the cross product.
    #

    fn cross2D( a : Vector2d ,  b : Vector2d):
        return a.x() * b.y()


    fn loadCovariance2D[M6xNf : AnyType , M2Nd : AnyType]( ge  :M6xNf,  hits_cov : M2Nd):
          # Index numerology:
          # i: index of the hits/point (0,..,3)
          # j: index of space component (x,y,z)
          # l: index of space components (x,y,z)
          # ge is always in sync with the index i and is formatted as:
          # ge[] ==> [xx, xy, yy, xz, yz, zz]
          # in (j,l) notation, we have:
          # ge[] ==> [(0,0), (0,1), (1,1), (0,2), (1,2), (2,2)]
          # so the index ge_idx corresponds to the matrix elements:
          # | 0  1  3 |
          # | 1  2  4 |
          # | 3  4  5 |
        constexpr uint32_t hits_in_fit = M6xNf::ColsAtCompileTime
        for i in range(hits_in_fit) :
            var ge_idx = 0
            var j = 0
            var l = 0
            hits_cov[i + j * hits_in_fit, i + l * hits_in_fit]= ge.col(i)[ge_idx]
            ge_idx = 2
            j = 1
            l = 1
            hits_cov[i + j * hits_in_fit, i + l * hits_in_fit] = ge.col(i)[ge_idx]
            ge_idx = 1
            j = 1
            l = 0
            hits_cov[i + l * hits_in_fit, i + j * hits_in_fit] = ge.col(i)[ge_idx] 
            hits_cov[i + j * hits_in_fit, i + l * hits_in_fit] = ge.col(i)[ge_idx]

    
    fn 
            


    
