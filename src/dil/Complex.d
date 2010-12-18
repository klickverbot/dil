/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.Complex;

import dil.Float;
import util.mpfr : mpfr_t;
import common;

alias dil.Float.Float Float;

/// A class for working with imaginary numbers.
class Complex
{
  Float re; /// The real part.
  Float im; /// The imaginary part.
  /// The length or magnitude of the vector.
  alias re mag;
  /// The angle of the vector.
  alias im phi;

  /// Constructs an initialized Float.
  this()
  {
    re = new Float();
    im = new Float();
  }

  /// Constructs from a Complex.
  this(Complex c)
  {
    re = c.re.dup();
    im = c.im.dup();
  }

  /// Constructs from two Floats.
  this(Float r, Float i=null)
  {
    re = r;
    im = i ? i : new Float();
  }

  /// Constructs from two mpfr_t instances.
  this(mpfr_t* r, mpfr_t* i=null)
  {
    re = new Float(r);
    im = i ? new Float(i) : new Float();
  }

  /// Constructs from two longs.
  this(long r, long i=0)
  {
    re = new Float(r);
    im = new Float(i);
  }

  /// Constructs from two ulongs.
  this(ulong r, ulong i=0)
  {
    re = new Float(r);
    im = new Float(i);
  }

  /// Constructs from two longs.
  this(double r, double i=0)
  {
    re = new Float(r);
    im = new Float(i);
  }

  /// Constructs from two strings.
  this(string r, string i)
  {
    re = new Float(r);
    im = new Float(i);
  }

  /// Constructs from a string.
  /// Params:
  ///   x = can be "a", "aj", "-ai", "a + bj", "a - bi" etc.
  this(string x)
  {
    if (!x.length)
      this();
    else
    {
      if (x[$-1] != '\0')
        x = x ~ '\0'; // Terminate with zero
      this(x.ptr);
    }
  }

  /// Constructs a Complex from a zero-terminated string.
  this(char* x)
  {
    set(x);
  }

  /// Parses the string and sets the real and imaginary parts. Returns itself.
  Complex set(char* x)
  {
    x = x && *x ? x : "0";

    char[] r_str, i_str;
    bool i_neg;
    auto p = x;
    while (*p == ' ')
      p++;
    x = p; // Let x point to the beginning of the number.
    if (*p == '-' || *p == '+')
      p++; // Skip for look-behind expression below (p[-1]).
    while (*p != 0 && *p != ' ' &&
           (*p != '-' && *p != '+' || p[-1] == 'e'))
      p++;
    if (p[-1] == 'i' || p[-1] == 'j')
      i_str = x[0..p-x]; // Only an imaginary component.
    else
    {
      r_str = x[0..p-x]; // Real component.
      while (*p == ' ') // Skip whitespace.
        p++;
      i_neg = *p == '-';
      if (i_neg || *p == '+') // ±bi
      {
        while (*++p == ' '){} // Skip whitespace.
        x = p; // Update beginning of the imaginary component.
        while (*p != 0 && *p != 'i' && *p != 'j')
          p++;
        if (*p != 0)
          i_str = x[0..p-x];
      }
    }

    re = new Float(r_str);
    im = new Float(i_str);
    if (i_neg)
      im.neg();
    return this;
  }

  /// For convenient construction of Complex numbers.
  static Complex opCall(Params...)(Params P)
  {
    return new Complex(P);
  }

  /// Clears this number and deallocates its data.
  void clear()
  {
    re.clear();
    im.clear();
  }

  /// Returns a deep copy of this number.
  Complex dup()
  {
    return new Complex(this);
  }

  /// Calculates z += x. Returns itself.
  Complex opAddAssign(Complex x)
  {
    re += x.re;
    im += x.im;
    return this;
  }

  /// Calculates z+x. Returns a new number.
  Complex opAdd(Complex x)
  {
    return new Complex() += x;
  }

  /// ditto
  Complex opAdd(uint x)
  {
    auto z = new Complex();
    z.re += x;
    return z;
  }

//   /// Calculates x-z.
//   Complex opAdd_r(T)(T x)
//   {
//     static if (is(T == Complex))
//       return x.dup() + this;
//     else
//       return new Complex(x) + this;
//   }

  /// Calculates z -= x. Returns itself.
  Complex opSubAssign(Complex x)
  {
    re -= x.re;
    im -= x.im;
    return this;
  }

  /// ditto
  Complex opSubAssign(uint x)
  {
    re -= x;
    return this;
  }

  /// Calculates z-x. Returns a new number.
  Complex opSub(T)(T x)
  {
    static if (is(T == Complex) || is(T == uint))
      return dup() -= x;
    else
      return dup() -= new Complex(x);
  }

//   /// Calculates x-z.
//   Complex opSub_r(T)(T x)
//   {
//     static if (is(T == Complex))
//       return x.dup() - this;
//     else
//       return new Complex(x) - this;
//   }

  /// Calculates z /= x. Returns itself.
  Complex opDivAssign(T:Complex)(T x)
  { // Special handling.
    if (x.im == 0)
      (re /= x.re),
      (im /= x.re);
    else
    {
      // auto n = x.re / x.im;
      // auto d = x.re * n + x.im;
      // auto r_ = re.dup();
      // re *= n; re += im; re /= d;
      // im *= n; im -= r_; im /= d;

      auto rx = x.re, ix = x.im;
      // d = x.re² + x.im²
      auto d = rx.dup().pow(2) += ix.dup().pow(2);
      auto r_ = re.dup();
      re *= rx; re += im * ix; re /= d;
      im *= rx; im -= r_ * ix; im /= d;
    }
    return this;
  }

  /// ditto
  Complex opDivAssign(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      alias x z;
    else
      auto z = new Float(x);
    re /= z;
    im /= z;
    return this;
  }

  /// Calculates z/x.  Returns a new number.
  Complex opDiv(T)(T x)
  {
    static if (is(T == Complex) || is(T == uint))
      alias x z;
    else
      auto z = new Complex(x);
    return dup() /= z;
  }

  // Cannot do the following because it conflicts with opDiv.
  // Complex opDiv_r(T)(T x)
  // { return new Complex(x) /= this; }

  /// Calculates x/z. Returns a new number.
  Complex opDiv_r(uint x)
  {
    return new Complex(cast(ulong)x) /= this;
  }

  /// ditto
  Complex opDiv_r(double x)
  {
    return new Complex(x) /= this;
  }

  /// ditto
  Complex opDiv_r(string x)
  {
    return new Complex(x) /= this;
  }

  /// ditto
  Complex opDiv_r(char* x)
  {
    return new Complex(x) /= this;
  }

  /// Calculates z *= x. Returns itself.
  Complex opMulAssign(T:Complex)(T x)
  { // Special handling.
    if (x.im == 0)
      (re *= x.re),
      (im *= x.re);
    else
    {
      auto r_ = re.dup();
      re *= x.re; re -= im*x.im;
      im *= x.re; im += r_*=x.im;
    }
    return this;
  }

  /// ditto
  Complex opMulAssign(T)(T x)
  {
    static if (is(T == Float) || is(T == uint))
      alias x z;
    else
      auto z = new Float(x);
    re *= z;
    im *= z;
    return this;
  }

  /// Calculates z*x. Returns a new number.
  Complex opMul(T)(T x)
  {
    static if (is(T == Complex) || is(T == uint))
      alias x z;
    else
      auto z = new Complex(x);
    return dup() *= z;
  }

//   /// Calculates x*z.
//   Complex opMul_r(T)(T x)
//   {
//     static if (is(T == Complex))
//       return x.dup() *= this;
//     else
//       return new Complex(x) *= this;
//   }

  /// Calculates z *= 2^x. Returns itself.
  Complex mul_2exp(uint x)
  {
    re.mul_2exp(x);
    im.mul_2exp(x);
    return this;
  }

  /// Calculates z /= 2^x. Returns itself.
  Complex div_2exp(uint x)
  {
    re.div_2exp(x);
    im.div_2exp(x);
    return this;
  }

  /// Compares z with x.
  int opEquals(T)(T x)
  {
    static if (is(T == Complex))
      alias x z;
    else
      auto z = new Complex(x);
    return re == z.re && im == z.im;
  }

  /// Returns a negated copy of this number.
  Complex opNeg()
  {
    auto n = dup();
    n.re.neg();
    n.im.neg();
    return n;
  }

  /// Negates this number. Returns itself.
  Complex neg()
  {
    re.neg();
    im.neg();
    return this;
  }

  /// Converts this number to polar representation. Returns itself.
  Complex polar()
  {
    auto phi_ = im.dup.atan2(re);
    re.hypot(im); // r = √(re^2 + im^2)
    phi = phi_;   // φ = arctan(im/re)
    return this;
  }

  /// Converts this number to cartesian representation. Returns itself.
  Complex cart()
  { // Looks weird but saves temporary variables.
    auto mag_ = mag.dup();
    mag *= phi.dup().cos(); // re = r*cos(φ)
    phi.sin() *= mag_;      // im = r*sin(φ)
    return this;
  }

  /// Calculates √z. Returns itself.
  Complex sqrt()
  { // √z = √(r.e^iφ) = √(r).e^(iφ/2)
    polar();
    mag.sqrt();
    phi /= 2;
    return cart();
  }

  /// Calculates z^w. Returns itself.
  Complex pow(T:Complex)(T w)
  { // z^w = e^(w*ln(z))
    ln() *= w; // z = ln(z); z *= w
    return exp(); // e^z
  }

  /// Calculates z^x. Returns itself.
  Complex pow(T)(T x)
  { // z² = (r.e^iφ)² = r².e^(2φi)
    polar();
    mag.pow(x);
    phi *= x;
    return cart();
  }

  /// Calculates e^z. Returns itself.
  Complex exp()
  { // e^z = e^(a+bi) = e^a * e^bi = e^a (cos(b) + i.sin(b))
    re.exp(); // r = e^Re(z)  φ = Im(z)
    return cart();
  }

  /// Calculates ln(z). Returns itself.
  Complex ln()
  { // ln(z) = ln(r.e^iφ) = ln(r) + ln(e^iφ) = ln(r) + iφ
    polar();
    mag.ln();
    return this;
  }

  /// Calculates log$(SUB a+bi)(w) = ln(w)/ln(a+bi). Returns a new number.
  Complex logz(Complex w)
  {
    return w.dup().ln() /= dup().ln();
  }

  /// Conjugates this number: conj(z) = Re(z) - Im(z). Returns itself.
  Complex conjugate()
  {
    im = -im;
    return this;
  }

  /// Returns a conjugated copy of this number.
  Complex conjugated()
  {
    return dup().conjugate();
  }

  /// Inverses this number: z = z^-1. Returns itself.
  Complex inverse()
  { // re/(a²+b²) - im/(a²+b²)
    auto d = re.dup().pow(2) += im.dup().pow(2);
    re /= d;
    im /= d.neg();
    return this;
  }

  /// Returns an inversed copy of this number.
  Complex inversed()
  {
    return dup().inverse();
  }

  /// Returns the polar angle: φ = arctan(b/a).
  Float arg()
  {
    return im.dup().atan2(re);
  }

  /// Returns the absolute value: |z| = √(re² + im²).
  Float abs()
  {
    return hypot(re, im);
  }

  /// Returns this float as a string.
  string toString()
  {
    return toString(30);
  }

  /// Returns this float as a string.
  string toString(uint precision)
  {
    auto im_sign = im.isNeg() ? "" : "+";
    return re.toString(precision) ~ im_sign ~ im.toString(precision) ~ "i";
  }
}

unittest
{
  Stdout("Testing class Complex.\n");

  alias Float F;
  alias Complex C;

  assert(-C(F(10), F(9)) == C(F(-10), F(-9)));
  assert(C(5., 20.) / 5. == C(1., 4.));
  assert(1. / C(5., 20.) == C(5., 20.).inverse());
  assert(C(3L, 2L) / C(4L,-6L) == C(0., 0.5));
  assert(C(3L, 4L).abs() == F(5));
  assert(C(3L, 4L).conjugate() == C(3L, -4L));
//   assert(C(3L, 4L).pow(2) == C(-7L, 24L));
//   assert(C(3L, 4L).sqrt() == C(2L, 1L));
  assert(C("3+4j") == C(3L, 4L));
  assert(C("-4e+2j") == C(0L, -400L));
}
