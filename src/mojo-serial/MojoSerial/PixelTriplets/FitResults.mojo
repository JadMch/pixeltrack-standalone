from MojoSerial.MojoBridge.Matrix import Matrix

struct Rfit:
    alias Vector2d = Matrix[Float64, 2, 1]
    alias Vector3d = Matrix[Float64, 3, 1]
    alias Vector4d = Matrix[Float64, 4, 1]
    alias Vector5d = Matrix[Float64, 5, 1]
    alias Matrix2d = Matrix[Float64, 2, 2]
    alias Matrix3d = Matrix[Float64, 3, 3]
    alias Matrix4d = Matrix[Float64, 4, 4]
    alias Matrix5d = Matrix[Float64, 5, 5]
    alias Matrix6d = Matrix[Float64, 6, 6]

    alias Matrix3xNd[N: Int] = Matrix[Float64, 3, N]

    struct circle_fit:
        var par : Vector3d #!< parameter: (X0,Y0,R)
        var cov : Matrix3d

        #/*!< covariance matrix: \n
        #|cov(X0,X0)|cov(Y0,X0)|cov( R,X0)| \n
        #|cov(X0,Y0)|cov(Y0,Y0)|cov( R,Y0)| \n
        #|cov(X0, R)|cov(Y0, R)|cov( R, R)|
        #*/ 

        var q : UInt32
        var chi2 : Float32

    struct line_fit:
        var par : Vector2d #//!<(cotan(theta),Zip)
        var cov : Matrix2d

        #/*!<
        #  |cov(c_t,c_t)|cov(Zip,c_t)| \n
        #  |cov(c_t,Zip)|cov(Zip,Zip)|
        #*/
        
        var chi2 : Float64

    struct helix_fit:
        var par : Vector5d #//!<(phi,Tip,pt,cotan(theta)),Zip)
        var cov : Matrix5d

        #/*!< ()->cov() \n
        #  |(phi,phi)|(Tip,phi)|(p_t,phi)|(c_t,phi)|(Zip,phi)| \n
        #  |(phi,Tip)|(Tip,Tip)|(p_t,Tip)|(c_t,Tip)|(Zip,Tip)| \n
        #  |(phi,p_t)|(Tip,p_t)|(p_t,p_t)|(c_t,p_t)|(Zip,p_t)| \n
        #  |(phi,c_t)|(Tip,c_t)|(p_t,c_t)|(c_t,c_t)|(Zip,c_t)| \n
        #  |(phi,Zip)|(Tip,Zip)|(p_t,Zip)|(c_t,Zip)|(Zip,Zip)|
        #*/
        
        var chi2_circle : Float32
        var chi2_line : Float32
            #//    Vector4d fast_fit;
        var q : UInt32;  #//!< particle charge
