module dcnum;

import std.bigint;
import std.math;
import std.string;
import std.format;
import std.algorithm;
import std.range;

struct DCNum {
  public:
    BigInt number;
    uint scale;
    uint div_scale = 0;  // keep scale when this is divided

  public:
    this(long v) {
      number = v;
      scale = 0;
    }
    this(string s) {
      long p = s.indexOf('.');

      if (p == -1) {
        // integer
        number = s;
        scale = 0;
      } else {
        // decimal
        number = s[0..p] ~ s[p+1..$];
        scale = cast(uint)(s.length - p) - 1;
      }
    }
    this(long v, uint div_scale) {
      this(v);
      this.div_scale = div_scale;
    }

    this(string s, uint div_scale) {
      this(s);
      this.div_scale = div_scale;
    }

    long toLong() {
      auto n = this.rescaled(0);
      return n.number.toLong();
    }

    DCNum rescaled(uint new_scale) {
      DCNum r;
      if (new_scale > scale) {
        r.number = number * pow(10, new_scale - scale);
      } else if (new_scale < scale) {
        r.number = number / pow(10, scale - new_scale);
      } else {
        r.number = number;
      }

      r.scale = new_scale;
      return r;
    }

    DCNum opBinary(string op:"+")(DCNum b) {
      DCNum r, a = this;
      r.scale = max(a.scale, b.scale);

      if (r.scale > a.scale) {
        a = a.rescaled(r.scale);
      } else if (r.scale > b.scale) {
        b = b.rescaled(r.scale);
      }
      r.number = a.number + b.number;

      return r;
    }

    DCNum opBinary(string op:"-")(DCNum b) {
      DCNum r, a = this;
      r.scale = max(a.scale, b.scale);

      if (r.scale > a.scale) {
        a = a.rescaled(r.scale);
      } else if (r.scale > b.scale) {
        b = b.rescaled(r.scale);
      }
      r.number = a.number - b.number;

      return r;
    }

    DCNum opBinary(string op:"*")(DCNum b) {
      DCNum r, a = this;
      r.scale = a.scale + b.scale;
      r.number = a.number * b.number;

      return r;
    }

    DCNum opBinary(string op:"/")(DCNum b) {
      DCNum r, a = this;
      r.scale = this.div_scale;

      uint scale = max(a.scale, b.scale);
      a = a.rescaled(scale + this.div_scale);
      b = b.rescaled(scale);

      r.number = a.number / b.number;
      return r;
    }

    bool opEquals()(auto ref const DCNum b) const { 
      return this.number == b.number && this.scale == b.scale;
    }

    string toString() {
      auto s ="%d".format(this.number);
      if (scale == 0) {
        return s;
      }

      if (number < 0) {
        s = s[1..$];
      }
      if (s.length <= scale) {
        auto r = "0.";
        foreach (_; 0..scale-s.length) {
          r ~= "0";
        }
        return ((number < 0) ? "-" : "") ~ r ~ s;
      }

      return ((number < 0) ? "-" : "") ~ s[0..$-scale] ~ "." ~ s[$-scale..$];
    }
}

unittest {
  import std.stdio;

  auto a = DCNum("35");
  auto b = DCNum("0.1");
  auto c = DCNum("-0.05");

  assert(a == DCNum("35"));
  assert(b == DCNum("0.1"));
  assert(c == DCNum("-0.05"));
  assert(a.scale == 0);
  assert(b.scale == 1);
  assert(c.scale == 2);

  assert(a + b == DCNum("35.1"));
  assert(a + c == DCNum("34.95"));
  assert(b + c == DCNum("0.05"));
  assert((a+b).scale == 1);
  assert((a+c).scale == 2);
  assert((b+c).scale == 2);

  assert(a - b == DCNum("34.9"));
  assert(a - c == DCNum("35.05"));
  assert(b - c == DCNum("0.15"));

  assert(a * b == DCNum("3.5"));
  assert(a * c == DCNum("-1.75"));
  assert(b * c == DCNum("-0.005"));
  
  a = DCNum("10");
  b = DCNum("3");
  c = DCNum("1.5");
  assert(a / b == DCNum("3"));
  assert(a / c == DCNum("6"));
  assert(b / c == DCNum("2"));

  a.div_scale = 4;
  assert(a / b == DCNum("3.3333"));

  assert(DCNum("1234").toString == "1234");
  assert(DCNum("-1234").toString == "-1234");
  assert(DCNum("1234.56").toString == "1234.56");
  assert(DCNum("-1234.56").toString == "-1234.56");
  assert(DCNum("0.1234").toString == "0.1234");
  assert(DCNum("-0.1234").toString == "-0.1234");

  assert(DCNum("1234").toLong == 1234);
  assert(DCNum("-1234").toLong == -1234);
  assert(DCNum("1234.56").toLong == 1234);
  assert(DCNum("-1234.56").toLong == -1234);
  assert(DCNum("0.1234").toLong == 0);
  assert(DCNum("-0.1234").toLong == -0);
}
