
#| 1) circle is parameterized as:                                              |
#|    C*[(X-Xp)**2+(Y-Yp)**2] - 2*alpha*(X-Xp) - 2*beta*(Y-Yp) = 0             |
#|    Xp,Yp is a point on the track;                                           |
#|    C = 1/r0 is the curvature  ( sign of C is charge of particle );          |
#|    alpha & beta are the direction cosines of the radial vector at Xp,Yp     |
#|    i.e.  alpha = C*(X0-Xp),                                                 |
#|          beta  = C*(Y0-Yp),                                                 |
#|    where center of circle is at X0,Y0.                                      |
#|                                                                             |
#|    Slope dy/dx of tangent at Xp,Yp is -alpha/beta.                          |
#| 2) the z dimension of the helix is parameterized by gamma = dZ/dSperp       |
#|    this is also the tangent of the pitch angle of the helix.                |
#|    with this parameterization, (alpha,beta,gamma) rotate like a vector.     |
#| 3) For tracks going inward at (Xp,Yp), C, alpha, beta, and gamma change sign|
#|

use math

struct CircleEq[T]:
    var m_xp : T  = 0
    var m_yp : T = 0
    var m_c : T = 0
    var m_alpha : T = 0
    var m_beta : T = 0
    fn __ini__(x1 : T, y1 : T,x2 : T, y2 : T,  x3 : T, y3 : T):
        self.compute(x1, y1, x2, y2, x3, y3)

    fn compute(self , x1 : T, y1 : T,x2 : T, y2 : T,  x3 : T, y3 : T):
        bool noflip = math.abs(x3 - x1) < math.abs(y3 - y1)
        let x1p = if noflip: x1 - x2 else: y1 - y2
        let y1p = if noflip: y1 - y2 else: x1 - x2
        let d12 = x1p * x1p + y1p * y1p
        let x3p = if noflip: x3 - x2 else: y3 - y2
        let y3p = if noflip: y3 - y2 else: x3 - x2
        let d32 = x3p * x3p + y3p * y3p

        let num = x1p * y3p - y1p * x3p # num also gives correct sign for CT
        let det = d12 * y3p - d32 * y1p

        let st2 = (d12 * x3p - d32 * x1p)
        let seq = det * det + st2 * st2
        let al2 = T(1.0) / math.sqrt(seq)
        let ct = T(2.0) *  num * al2
        self.al2 *= det
        self.m_xp = x2
        self.m_yp = y2
        self.m_c = if noflip : al2 else : -be2
        self.m_beta = if noflip : be2 else : -al2 
    #dca to origin divided by curvature
    fn dca0(self) -> T:
        let x = self.m_c * self.m_xp + self.m_alpha
        let y = self.m_c * self.m_yp + self.m_beta
        return math.sqrt(x * x + y * y) - T(1)
    #dca to given point (divided by curvature)
    fn dca(self , x : T , y : T) -> T:
        let x = self.m_c * (self.m_xp - x ) + self.m_alpha
        let y = self.m_c * (self.m_yp - y) + self.m_beta
        return math.sqrt(x * x + y * y) - T(1)
    
    #curvature
    fn curative(self):
        return self.m_c 

    fn cosdir(self, x: T, y: T) -> (T, T):
        return (
        self.m_alpha - self.m_c * (x - self.m_xp),
        self.m_beta - self.m_c * (y - self.m_yp)
    )
        
    fn center (self) -> (T, T):
        return (
            self.m_xp + self.m_alpha / self.m_c , 
            self.m_yp + self.m_beta / self.m_x
        )

    fn radius(self):
        return T(1) / self.m_c