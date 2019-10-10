module dcnum;

import std.traits : isIntegral, isUnsigned;
import std.typecons : tuple, Tuple;
import std.conv : to, ConvOverflowException;
import std.math : log10;
import std.format : format;
import std.array : join;
import std.algorithm : reverse, min, max, all, map;
import std.exception;
import std.random : rndGen, Random, uniform;

const BASE = 10;

class DCNumException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure
    {
        super(msg, file, line);
    }
}

struct DCNum
{
private:
    bool sign; // when true this value is negative;
    uint scale; // number of digits after the decimal point.
    ubyte[] value; // array of digits. from higher digit to lower digit.

    long len() const pure
    {
        return this.value.length - this.scale;
    }

    this(T)(bool sign, T scale, in ubyte[] value) pure if (isIntegral!T)
    {
        this.sign = sign;
        this.scale = scale.to!uint;
        this.value = value.dup;
    }

    this(in ubyte[] value) pure
    {
        this.sign = false;
        this.scale = 0;
        this.value = value.dup;
    }

    void rescale(uint new_scale) pure
    {
        if (new_scale > this.scale)
        {
            this.value ~= new ubyte[](new_scale - this.scale);
        }
        else if (new_scale < this.scale)
        {
            this.value.length = this.value.length - (this.scale - new_scale);
        }
        this.scale = new_scale;
    }

    DCNum rescaled(uint new_scale) pure const
    {
        DCNum copy = DCNum(this);
        copy.rescale(new_scale);
        return copy;
    }

    unittest
    {
        assert(DCNum(1).rescaled(5) == DCNum("1.00000"));
        assert(DCNum("1.234567").rescaled(5) == DCNum("1.23456"));
        assert(DCNum("625.0000").rescaled(1) == DCNum("625.0"));
    }

public:
    /// copy constructor
    this(in DCNum num) pure
    {
        this.sign = num.sign;
        this.scale = num.scale;
        this.value = num.value.dup;
    }
    /// constructor from Integral values
    this(INT)(INT val) pure if (isIntegral!INT)
    {

        // zero is special case
        if (val == 0)
        {
            this.sign = false;
            this.value = [0];
            this.scale = 0;
            return;
        }

        this.sign = false;
        static if (!isUnsigned!INT)
        {
            if (val < 0)
            {
                this.sign = true;
                val = cast(INT)(0 - val);
            }
        }

        uint index = 0;
        ubyte[] buf = new ubyte[](log10(INT.max).to!uint + 1);
        while (val != 0)
        {
            buf[index++] = cast(ubyte)(val % BASE);
            val = val / BASE;
        }

        this.value = reverse(buf[0 .. index]);
        this.scale = 0;
    }

    unittest
    {
        const zero = DCNum(0);
        assert(zero.sign == false);
        assert(zero.len == 1);
        assert(zero.scale == 0);
        assert(zero.value == [0]);

        const one = DCNum(1);
        assert(one.sign == false);
        assert(one.len == 1);
        assert(one.scale == 0);
        assert(one.value[0] == 1);

        const minus = DCNum(-1);
        assert(minus.sign == true);
        assert(minus.len == 1);
        assert(minus.scale == 0);
        assert(minus.value[0] == 1);

        const large = DCNum(9876543210987654321u);
        assert(large.sign == false);
        assert(large.len == 19);
        assert(large.scale == 0);
        assert(large.value == [
                9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 9, 8, 7, 6, 5, 4, 3, 2, 1
                ]);
    }

    /// constructor from string.
    this(string value) pure
    {
        // sign
        ulong p = 0;
        this.sign = false;

        // "+" and "-" are invalid. so when leading + or - exists, buffer size must be longer than 1
        if (value.length > p + 1 && value[p] == '+')
        {
            p++;
        }
        else if (value.length > p + 1 && value[p] == '-')
        {
            this.sign = true;
            p++;
        }

        // skip leading zeroes
        while (value.length > p && value[p] == '0')
        {
            p++;
        }

        // read values
        this.value = new ubyte[](value.length - p);
        long index = 0;
        int len = 0;
        this.scale = 0;
        while (value.length > p)
        {
            if ('0' <= value[p] && value[p] <= '9')
            {
                this.value[index++] = cast(ubyte)(value[p] - '0');
                p++;
                len++;
            }
            else if (value[p] == '.' && value.length > p + 1)
            {
                p++;
                break;
            }
            else
            {
                throw new DCNumException("illegal character: %c".format(value[p]));
            }
        }
        while (value.length > p)
        {
            if ('0' <= value[p] && value[p] <= '9')
            {
                this.value[index++] = cast(ubyte)(value[p] - '0');
                p++;
                this.scale++;
            }
            else
            {
                throw new DCNumException("illegal character: %c".format(value[p]));
            }
        }

        // shrink
        this.value.length = (len + this.scale);

        // zero
        if (this.len == 0 && this.scale == 0)
        {
            this.sign = false;
            this.scale = 0;
            this.value = [0];
        }
    }

    unittest
    {
        const zero = DCNum("0");
        assert(zero.sign == false);
        assert(zero.len == 1);
        assert(zero.scale == 0);
        assert(zero.value == [0]);

        const minus_zero = DCNum("-0");
        assert(minus_zero.sign == false);
        assert(minus_zero.len == 1);
        assert(minus_zero.scale == 0);
        assert(minus_zero.value == [0]);

        const floating = DCNum("-1234.56789");
        assert(floating.sign == true);
        assert(floating.len == 4);
        assert(floating.scale == 5);
        assert(floating.value == [1, 2, 3, 4, 5, 6, 7, 8, 9]);

        const floating_zero = DCNum("0.56789");
        assert(floating_zero.sign == false);
        assert(floating_zero.len == 0);
        assert(floating_zero.scale == 5);
        assert(floating_zero.value == [5, 6, 7, 8, 9]);

        const trailing_zero = DCNum("-1234.567890");
        assert(trailing_zero.sign == true);
        assert(trailing_zero.len == 4);
        assert(trailing_zero.scale == 6);
        assert(trailing_zero.value == [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);

        const large = DCNum("98765432109876543210");
        assert(large.sign == false);
        assert(large.len == 20);
        assert(large.scale == 0);
        assert(large.value == [
                9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
                ]);

        assertThrown!DCNumException(DCNum("+"));
        assertThrown!DCNumException(DCNum("-"));
        assertThrown!DCNumException(DCNum("."));
        assertThrown!DCNumException(DCNum("0."));
        assertThrown!DCNumException(DCNum("1."));
        assertThrown!DCNumException(DCNum("1..23"));
        assertNotThrown!DCNumException(DCNum(".0"));
    }

    string toString() const pure
    {
        string s = "";
        if (this.sign)
        {
            s ~= "-";
        }

        if (this.len == 0)
        {
            s ~= "0";
        }
        else
        {
            s ~= this.value[0 .. this.len].map!(x => x.to!string).join("");
        }

        if (this.scale > 0)
        {
            s ~= ".";
            s ~= this.value[this.len .. this.len + this.scale].map!(x => x.to!string).join("");
        }

        return s;
    }

    unittest
    {
        assert(DCNum("0").to!string == "0");
        assert(DCNum("-0").to!string == "0");
        assert(DCNum("100").to!string == "100");
        assert(DCNum("0.100").to!string == "0.100");
        assert(DCNum("-10.1").to!string == "-10.1");
    }

    T to(T)() const pure if (is(T : string))
    {
        return this.toString();
    }

    T to(T)() const pure if (isIntegral!(T))
    {
        if (DCNum.cmp(this, DCNum(T.max)) > 0)
        {
            throw new ConvOverflowException("Conversion positive overflow");
        }
        static if (isUnsigned!(T))
        {
            if (this.sign)
            {
                throw new ConvOverflowException("Conversion negative overflow");
            }
        }

        T v = cast(T)(0);
        foreach (x; this.value[0 .. this.len])
        {
            v = cast(T)(v * BASE + x);
        }
        if (this.sign)
        {
            v = cast(T)(0 - v);
        }
        return v;
    }

    unittest
    {
        assert(DCNum("10000").to!int == 10000);
        assert(DCNum("10000.2345").to!int == 10000);
        assert(DCNum("10000.9").to!int == 10000);
        assert(DCNum("0.9").to!int == 0);
        assert(DCNum(-1).to!byte == -1);
        assertThrown!ConvOverflowException(DCNum(10000).to!ubyte);
        assertThrown!ConvOverflowException(DCNum(-1).to!ubyte);
        assertThrown!ConvOverflowException(DCNum(10000).to!ubyte);
    }

    bool isZero() pure const
    {
        return this.value.all!"a == 0";
    }

    unittest
    {
        assert(DCNum("0").isZero);
        assert(DCNum("-0").isZero);
        assert((DCNum("10") - DCNum("10")).isZero);
        assert(!(DCNum("10") - DCNum("9.99999999")).isZero);
    }

    /// if lhs is larger than rhs, return 1. if lhs is smaller than rhs, then return -1. if lhs and rhs are same, return 0;
    private static int cmp(in DCNum lhs, in DCNum rhs, bool ignore_sign = false) pure
    {
        // compare sign
        if (lhs.sign == false && rhs.sign == true && ignore_sign == false)
        {
            return 1;
        }
        else if (lhs.sign == true && rhs.sign == false && ignore_sign == false)
        {
            return -1;
        }
        int sign = (lhs.sign && ignore_sign == false) ? -1 : 1;

        // compare size of integer part
        if (lhs.len > rhs.len)
        {
            return sign;
        }
        else if (lhs.len < rhs.len)
        {
            return -sign;
        }

        // compare integer parts
        foreach (i; 0 .. lhs.len)
        {
            if (lhs.value[i] > rhs.value[i])
            {
                return sign;
            }
            else if (lhs.value[i] < rhs.value[i])
            {
                return -sign;
            }
        }

        // compare fraction parts
        foreach (i; 0 .. min(lhs.scale, rhs.scale))
        {
            if (lhs.value[lhs.len + i] > rhs.value[rhs.len + i])
            {
                return sign;
            }
            else if (lhs.value[lhs.len + i] < rhs.value[rhs.len + i])
            {
                return -sign;
            }
        }

        if (lhs.scale > rhs.scale)
        {
            if (lhs.value[(lhs.len + rhs.scale) .. $].all!"a == 0")
            {
                return 0;
            }
            return sign;
        }
        else
        {
            if (rhs.value[(rhs.len + lhs.scale) .. $].all!"a == 0")
            {
                return 0;
            }
            return -sign;
        }
    }

    bool opEquals(in DCNum rhs) const pure
    {
        return DCNum.cmp(this, rhs) == 0;
    }

    bool opEquals(T)(T rhs) const pure if (isIntegral!(T))
    {
        if (this.scale != 0)
        {
            return false;
        }
        if (rhs == 0 && this.len == 1 && this.value[0] == 0)
        {
            return true;
        }
        if (rhs < 0)
        {
            if (this.sign == false)
            {
                return false;
            }
            rhs = -rhs;
        }

        long i = this.len - 1;
        while (true)
        {
            const bool x = rhs == 0;
            const bool y = i < 0;
            if (x && y)
            {
                return true;
            }
            if (x || y)
            {
                return false;
            }

            if (rhs % BASE != this.value[i])
            {
                return false;
            }
            rhs = rhs / BASE;
            i--;
        }
        assert(false); // unreachable
    }

    int opCmp(in DCNum rhs) const pure
    {
        return DCNum.cmp(this, rhs);
    }

    unittest
    {
        assert(DCNum(0) == DCNum(0));
        assert(DCNum(1) > DCNum(0));
        assert(DCNum(1) < DCNum(2));
        assert(DCNum(1) > DCNum(-2));
        assert(DCNum(-1) > DCNum(-2));
        assert(DCNum("0.1") == DCNum("0.1"));
        assert(DCNum("0.1") == DCNum("0.10"));

        assert(DCNum(0) == 0);
        assert(DCNum(1) == 1);
        assert(DCNum(-1) == -1);
    }

    /// add lhs and rhs
    /// this function ignore sign
    private static DCNum add(in DCNum lhs, in DCNum rhs) pure
    {
        ubyte[] lhs_value = lhs.value.dup;
        ubyte[] rhs_value = rhs.value.dup;

        // align digits before the decimal point
        if (lhs.len > rhs.len)
        {
            rhs_value = new ubyte[](lhs.len - rhs.len) ~ rhs_value;
        }
        else if (lhs.len < rhs.len)
        {
            lhs_value = new ubyte[](rhs.len - lhs.len) ~ lhs_value;
        }

        // align digits after the decimal point
        if (lhs.scale > rhs.scale)
        {
            rhs_value = rhs_value ~ new ubyte[](lhs.scale - rhs.scale);
        }
        else if (lhs.scale < rhs.scale)
        {
            lhs_value = lhs_value ~ new ubyte[](rhs.scale - lhs.scale);
        }

        // addition digit by digit
        ubyte carry = 0;
        ubyte[] buf = new ubyte[](lhs_value.length);
        foreach_reverse (i; 0 .. lhs_value.length)
        {
            buf[i] = (lhs_value[i] + rhs_value[i] + carry).to!(ubyte);
            if (buf[i] >= BASE)
            {
                carry = 1;
                buf[i] = buf[i] % BASE;
            }
            else
            {
                carry = 0;
            }
        }

        const uint new_scale = max(lhs.scale, rhs.scale);
        if (carry)
        {
            buf = cast(ubyte[])[1] ~ buf;
        }
        return DCNum(false, new_scale, buf);
    }

    /// subtract rhs from lhs. lhs must be larger than rhs on magnitude
    private static DCNum sub(in DCNum lhs, in DCNum rhs) pure
    {
        ubyte[] lhs_value = lhs.value.dup;

        // align digits after the decimal point
        if (lhs.scale < rhs.scale)
        {
            lhs_value = lhs_value ~ new ubyte[](rhs.scale - lhs.scale);
        }

        ubyte borrow = 0;
        const pad = lhs.len - rhs.len;
        foreach_reverse (i; 0 .. (rhs.len + rhs.scale))
        {
            if (lhs_value[pad + i] < rhs.value[i] + borrow)
            {
                lhs_value[pad + i] = cast(ubyte)((10 + lhs_value[pad + i]) - (rhs.value[i] + borrow));
                borrow = 1;
            }
            else
            {
                lhs_value[pad + i] = cast(ubyte)(lhs_value[pad + i] - (rhs.value[i] + borrow));
                borrow = 0;
            }
        }
        if (borrow)
        {
            lhs_value[pad - 1]--;
        }

        uint new_scale = max(lhs.scale, rhs.scale);

        // shrink value
        uint p = 0;
        while (p < lhs.len && lhs_value[p] == 0)
        {
            p++;
        }
        lhs_value = lhs_value[p .. $];

        return DCNum(false, new_scale, lhs_value);
    }

    DCNum opBinary(string op : "+")(in DCNum rhs) const pure
    {
        if (this.sign == false && rhs.sign == false)
        {
            return DCNum.add(this, rhs);
        }
        else if (this.sign == true && rhs.sign == true)
        {
            auto v = DCNum.add(this, rhs);
            v.sign = true;
            return v;
        }
        else
        {
            switch (DCNum.cmp(this, rhs, true))
            {
            case 0:
                return DCNum(0);
            case 1:
                auto v = DCNum.sub(this, rhs);
                v.sign = this.sign;
                return v;
            case -1:
                auto v = DCNum.sub(rhs, this);
                v.sign = rhs.sign;
                return v;
            default:
                assert(0);
            }
        }
    }

    unittest
    {
        assert((DCNum(1) + DCNum(1)).to!string == "2");
        assert((DCNum(1) + DCNum(2)).to!string == "3");
        assert((DCNum(-2) + DCNum(1)).to!string == "-1");
        assert((DCNum(2) + DCNum(-1)).to!string == "1");
        assert((DCNum(2) + DCNum(-4)).to!string == "-2");
        assert((DCNum(-2) + DCNum(-4)).to!string == "-6");

        assert((DCNum("0.1") + DCNum("-0.05")).to!string == "0.05");
        assert((DCNum("0.1") + DCNum("-0.050")).to!string == "0.050");
        assert((DCNum("10.1") + DCNum("-5")).to!string == "5.1");
    }

    DCNum opBinary(string op : "-")(in DCNum rhs) pure const
    {
        if (this.sign == false && rhs.sign == true)
        {
            return DCNum.add(this, rhs);
        }
        else if (this.sign == true && rhs.sign == false)
        {
            auto v = DCNum.add(this, rhs);
            v.sign = true;
            return v;
        }
        else
        {
            switch (DCNum.cmp(this, rhs, true))
            {
            case 0:
                return DCNum(0);
            case 1:
                auto v = DCNum.sub(this, rhs);
                v.sign = this.sign;
                return v;
            case -1:
                auto v = DCNum.sub(rhs, this);
                v.sign = !rhs.sign;
                return v;
            default:
                assert(0);
            }
        }
    }

    unittest
    {
        assert((DCNum(1) - DCNum(1)).to!string == "0");
        assert((DCNum(1) - DCNum(2)).to!string == "-1");
        assert((DCNum(-2) - DCNum(1)).to!string == "-3");
        assert((DCNum(2) - DCNum(-1)).to!string == "3");
        assert((DCNum(2) - DCNum(-4)).to!string == "6");
        assert((DCNum(-2) - DCNum(-4)).to!string == "2");

        assert((DCNum("0.1") - DCNum("-0.05")).to!string == "0.15");
        assert((DCNum("0.1") - DCNum("-0.050")).to!string == "0.150");
        assert((DCNum("10.1") - DCNum("-5")).to!string == "15.1");
    }

    /// simple multiply by karatsuba method.
    /// this function ignores sign and scale, caller should set len and scale ownself
    private static DCNum mul(in DCNum lhs, in DCNum rhs) pure
    {
        // utilities
        const bytes_to_long = (in ubyte[] xs) {
            long y = 0;
            foreach (x; xs)
            {
                y = y * 10 + x;
            }
            return y;
        };
        const long_to_bytes = (long x) {
            ubyte[] xs = [];
            while (x != 0)
            {
                xs ~= cast(ubyte)(x % 10);
                x /= 10;
            }
            return reverse(xs);
        };
        const max_base_size = cast(int)(log10(long.max) / 2);

        // decide base size
        const lhs_size = (lhs.len + lhs.scale + 1) / 2;
        const rhs_size = (rhs.len + rhs.scale + 1) / 2;

        if (lhs_size > max_base_size)
        {
            // split lhs = high || low
            const half_len = (lhs.len + lhs.scale) / 2;
            const lhs_low = DCNum(lhs.value[half_len .. $]);
            const lhs_high = DCNum(lhs.value[0 .. half_len]);

            // high * rhs  || low * rhs
            const low_result = DCNum.mul(lhs_low, rhs);
            const high_result = DCNum.mul(lhs_high, rhs);
            const high_value = high_result.value ~ new ubyte[](lhs.value.length - half_len);
            return DCNum(high_value) + low_result;
        }
        if (rhs_size > max_base_size)
        {
            // split rhs = high || low
            const half_len = (rhs.len + rhs.scale) / 2;
            const rhs_low = DCNum(rhs.value[half_len .. $]);
            const rhs_high = DCNum(rhs.value[0 .. half_len]);

            // high * lhs  || low * lhs
            const low_result = DCNum.mul(rhs_low, lhs);
            const high_result = DCNum.mul(rhs_high, lhs);
            const high_value = high_result.value ~ new ubyte[](rhs.value.length - half_len);
            return DCNum(high_value) + low_result;
        }

        const base_size = max(lhs_size, rhs_size);

        // if both are small, calculate as long
        if (lhs.len + lhs.scale + rhs.len + rhs.scale < max_base_size)
        {
            const long x = bytes_to_long(lhs.value);
            const long y = bytes_to_long(rhs.value);
            const long z = x * y;
            ubyte[] buf = long_to_bytes(z);
            const uint new_scale = lhs.scale + rhs.scale;
            return DCNum(buf);
        }

        assert(base_size <= max_base_size); // TODO

        // split x -> x1 || x0
        const long x0 = bytes_to_long(lhs.value[max(cast(int)($ - base_size), 0) .. $]);
        const long x1 = bytes_to_long(lhs.value[0 .. max(cast(int)($ - base_size), 0)]);
        const long y0 = bytes_to_long(rhs.value[max(cast(int)($ - base_size), 0) .. $]);
        const long y1 = bytes_to_long(rhs.value[0 .. max(cast(int)($ - base_size), 0)]);

        // karatsuba algorithm
        const long z0 = x0 * y0;
        const long z2 = x1 * y1;
        const long z1 = z2 + z0 - (x1 - x0) * (y1 - y0); // buf0 = z0, buf1 = z1 * base, buf2 = z2 * base^2
        const buf0 = long_to_bytes(z0);
        const buf1 = long_to_bytes(z1) ~ new ubyte[](base_size);
        const buf2 = long_to_bytes(z2) ~ new ubyte[](base_size * 2); // convert to DCNum
        const v0 = DCNum(buf0);
        const v1 = DCNum(buf1);
        const v2 = DCNum(buf2); // summing
        auto v = v0 + v1 + v2;

        // remove reading zeroes
        long p = 0;
        while (p < v.len && v.value[p] == 0)
        {
            p++;
        }
        v.value = v.value[p .. $];
        return v;
    }

    /// multiply lhs by integer rhs
    /// this function ignores len and scale properties
    private static DCNum mul_by_const(T)(in DCNum lhs, T rhs) pure 
            if (isIntegral!(T))
    in
    {
        assert((BASE - 1) * rhs <= ubyte.max);
    }
    do
    {
        if (rhs == 0)
        {
            return DCNum(0);
        }
        if (rhs == 1)
        {
            return DCNum(lhs);
        }

        ubyte[] buf = new ubyte[](lhs.value.length + 1);
        int carry = 0;
        long i = lhs.value.length;
        foreach_reverse (x; lhs.value)
        {
            const y = x * rhs + carry;
            buf[i--] = (y % BASE).to!ubyte;
            carry = cast(int)(y / BASE);
        }
        if (carry != 0)
        {
            buf[i--] = carry.to!ubyte;
        }
        return DCNum(buf[i + 1 .. $]);
    }

    unittest
    {
        alias TestCase = Tuple!(DCNum, int, string);
        auto testcases = [
            TestCase(DCNum(500), 2, "1000"),
            TestCase(DCNum("33333333"), 3, "99999999"),
            TestCase(DCNum("123456789"), 5, "617283945")
        ];
        foreach (t; testcases)
        {
            auto r = DCNum.mul_by_const(t[0], t[1]).to!string;
            assert(r == t[2], "Case: %s, Got: %s".format(t, r));
        }
    }

    DCNum mul(in DCNum rhs, uint scale) const pure
    {
        if (this.isZero || rhs.isZero)
        {
            return DCNum(0);
        }

        auto v = DCNum.mul(this, rhs);
        int v_scale = this.scale + rhs.scale;
        if (v.value.length < v_scale)
        {
            v.value = new ubyte[](v_scale - v.value.length) ~ v.value;
        }
        v.scale = max(scale, min(this.scale, rhs.scale));
        if (v.scale < v_scale)
        {
            v.value.length = v.value.length - (v_scale - v.scale);
        }

        if (this.sign != rhs.sign)
        {
            v.sign = true;
        }
        return v;
    }

    unittest
    {
        import std.stdio;

        assert(DCNum("1.00").mul(DCNum("0.5"), 2) == DCNum("0.50"));
        assert(DCNum("1.00").mul(DCNum("0.5"), 3) == DCNum("0.50"));
        assert(DCNum("1.000").mul(DCNum("0.5"), 2) == DCNum("0.50"));
        assert(DCNum("3.00").mul(DCNum("0.5"), 2) == DCNum("1.50"));
    }

    DCNum opBinary(string op : "*")(in DCNum rhs) const pure
    {
        return this.mul(rhs, this.scale + rhs.scale);
    }

    unittest
    {
        // normal values
        assert((DCNum(0) * DCNum(1)).to!string == "0");
        assert((DCNum(1) * DCNum(1)).to!string == "1");
        assert((DCNum(-1) * DCNum(1)).to!string == "-1");
        assert((DCNum(-1) * DCNum(-1)).to!string == "1");
        assert((DCNum(100000) * DCNum(70)).to!string == "7000000");
        assert((DCNum("987654321123456789") * DCNum("100000000"))
                .to!string == "98765432112345678900000000");

        // decimal values
        assert((DCNum("2") * DCNum("0.5")) == DCNum("1.0"));
        assert((DCNum("100000.123") * DCNum("100")).to!string == "10000012.300");
        assert((DCNum("0.123") * DCNum("0.01")).to!string == "0.00123"); // very large number
        assert((DCNum("100000.123") * DCNum("0.01")).to!string == "1000.00123"); // very large number
        assert((DCNum("9876543211234567899") * DCNum("100000000"))
                .to!string == "987654321123456789900000000");

        // rsa
        const p = DCNum("7857843807357322428021380248993576655206988614176418792379176652835565059295420706559476442876718401226381634767797717201944708260927696952220575206571167");
        const q = DCNum("11022865926124182806180388767382016652191532553299862348953322076764410256860215835703669245291707730752129977734682225290368939156485722324614823488258901");
        assert((p * q).to!string == "86615958756924946592957282448568720038805999499540908216698775245619824596674378512195525165203154029569489225605263626685364659699870945114711447932248705556536031296400659122760841627071717950914771235328300476962435317906251410048014717963467669606882231758796075711787284426301244369129372556726977707467");
    }

    /// divide lhs by rhs. this function ignores its scale and sign
    /// this function using Knuth's Algorithm D
    private static DCNum div(in DCNum lhs, in DCNum rhs) pure
    {
        if (rhs.isZero)
        {
            throw new DCNumException("Divide by zero");
        }
        if (lhs.isZero)
        {
            return DCNum(0);
        }

        DCNum l = DCNum(lhs), r = DCNum(rhs);
        l.sign = false;
        r.sign = false;
        l.scale = 0;
        r.scale = 0;

        if (DCNum.cmp(l, r) < 0)
        {
            return DCNum(0);
        }
        while (l.value.length <= 2 || r.value.length <= 2)
        {
            l.value ~= [0];
            r.value ~= [0];
        }

        // normalize
        auto d = ((BASE - 1) / r.value[0]).to!long;
        auto rr = DCNum.mul_by_const(r, d);
        if (rr.value[0] < BASE / 2)
        {
            d = (BASE / (r.value[0] + 1)).to!long;
        }
        if (d != 1)
        {
            l = DCNum.mul_by_const(l, d);
            r = DCNum.mul_by_const(r, d);
        }

        ubyte[] q = [];
        const n = l.len - r.len;
        for (long j = n; j >= 0; j--)
        {
            // guess q
            auto qguess = (l.value[0] * BASE + l.value[1]) / r.value[0];
            auto rguess = (l.value[0] * BASE + l.value[1]) - qguess * r.value[0];
            if (qguess == BASE && rguess == 0)
            {
                auto x = DCNum(r);
                x.value ~= new ubyte[](j);
                if (DCNum.cmp(l, x) == 0)
                {
                    q ~= cast(ubyte[])[1] ~ new ubyte[](j);
                    break;
                }
            }
            while (rguess < BASE && (qguess >= BASE || qguess * r.value[1]
                    > BASE * rguess + l.value[2]))
            {
                qguess--;
                rguess += r.value[0];
            }

            // multiple and substract
            auto x = DCNum.mul_by_const(r, qguess);
            if (j > 0)
            {
                x.value ~= new ubyte[](j - 1);
            }

            // fix guess
            while (DCNum.cmp(l, x) < 0)
            {
                qguess--;
                x = DCNum.mul_by_const(r, qguess);
                if (j > 0)
                {
                    x.value ~= new ubyte[](j - 1);
                }
            }

            l = DCNum.sub(l, x);
            q ~= qguess.to!ubyte;
            if (DCNum.cmp(l, r) <= 0)
            {
                if (j > 0)
                {
                    q ~= new ubyte[](j - 1);
                }
                break;
            }
        }

        return DCNum(q);
    }

    unittest
    {
        assert(DCNum.div(DCNum(10), DCNum(5)) == 2);
        assert(DCNum.div(DCNum(1000), DCNum(5)) == 200);
        assert(DCNum.div(DCNum(1000), DCNum(50)) == 20);
        assert(DCNum.div(DCNum("100000000000"), DCNum(5)).to!string == "20000000000");
        assert(DCNum.div(DCNum("11044102452163169934"),
                DCNum("10319522097943752571")).to!string == "1");

        // random case
        foreach (_; 0 .. 100)
        {
            auto rnd = rndGen();
            auto x = uniform!ulong(rnd);
            auto y = uniform!ulong(rnd);
            auto r = DCNum.div(DCNum(x), DCNum(y)).to!string;
            assert(r == (x / y).to!string, "Case: %d / %d, Got: %s".format(x, y, r));
        }
    }

    DCNum div(in DCNum rhs, uint scale) const pure
    {
        if (this.isZero)
        {
            return DCNum(0);
        }
        DCNum lhs = DCNum(this);
        lhs.value ~= new ubyte[](scale + rhs.scale);
        lhs.scale = 0;

        auto v = DCNum.div(lhs, rhs);
        v.value.length = v.value.length - this.scale;
        if (v.value.length < scale)
        {
            v.value = new ubyte[](scale - v.value.length) ~ v.value;
        }
        v.scale = scale;
        if (this.sign != rhs.sign)
        {
            v.sign = true;
        }
        return v;
    }

    unittest
    {
        assert(DCNum(2).div(DCNum(2), 10).to!string == "1.0000000000");
        assert(DCNum(10).div(DCNum(3), 10).to!string == "3.3333333333");
        assert(DCNum(10).div(DCNum("3.0"), 10).to!string == "3.3333333333");
        assert(DCNum(10).div(DCNum("3.3"), 10).to!string == "3.0303030303");
        assert(DCNum(10).div(DCNum("3.333333333333333333"), 10).to!string == "3.0000000000");
        assert(DCNum(5).div(DCNum(10), 10).to!string == "0.5000000000");
        assert(DCNum("123456789.0987654321").div(DCNum("555"), 10).to!string == "222444.6650428205");
        assert(DCNum("10.000").div(DCNum("2"), 1).to!string == "5.0");
        assert(DCNum("10.000").div(DCNum("-2"), 1).to!string == "-5.0");
        assert(DCNum("-10.000").div(DCNum("2"), 1).to!string == "-5.0");
        assert(DCNum("138458412558.000000").div(DCNum("74.4200006"), 5) == DCNum("1860500019.37248"));
        assert(DCNum("33333333333333333333333333")
                .div(DCNum("248352686608866080.9427714159"), 11) == DCNum("134217727.97582189752"));
        assert(DCNum(2).div(DCNum("1.5"), 1) == DCNum("1.3"));
        assert(DCNum(1).div(DCNum("625.000000"), 4) == DCNum("0.0016"));
    }

    DCNum opBinary(string op : "/")(in DCNum rhs) const pure
    {
        return this.div(rhs, max(this.scale, rhs.scale));
    }

    unittest
    {
        assert((DCNum(5) / DCNum(3)).to!string == "1");
        assert((DCNum(10) / DCNum(3)).to!string == "3");
        assert((DCNum(10) / DCNum("3.0")).to!string == "3.3");
        assert((DCNum(-10) / DCNum("0.50")).to!string == "-20.00");
        const n = DCNum("86615958756924946592957282448568720038805999499540908216698775245619824596674378512195525165203154029569489225605263626685364659699870945114711447932248705556536031296400659122760841627071717950914771235328300476962435317906251410048014717963467669606882231758796075711787284426301244369129372556726977707467");
        const q = DCNum("11022865926124182806180388767382016652191532553299862348953322076764410256860215835703669245291707730752129977734682225290368939156485722324614823488258901");
        assert((n / q).to!string == "7857843807357322428021380248993576655206988614176418792379176652835565059295420706559476442876718401226381634767797717201944708260927696952220575206571167");
    }

    DCNum mod(in DCNum rhs, uint scale) const pure
    {
        auto r = this.div(rhs, scale);
        auto m = this - r * rhs;
        return m;
    }

    unittest
    {
        assert(DCNum(10).mod(DCNum(3), 0) == 1);
        assert(DCNum(10).mod(DCNum(3), 2) == DCNum("0.01"));
        assert(DCNum(10).mod(DCNum("3.0"), 0) == DCNum("1.0"));
        assert(DCNum(10).mod(DCNum("3.0"), 2) == DCNum("0.010"));
        assert(DCNum(10).mod(DCNum("5.0"), 1000) == DCNum(0));
        assert(DCNum(-2).mod(DCNum("1.60"), 0) == DCNum("-0.40"));
    }

    DCNum opBinary(string op : "%")(in DCNum rhs) const pure
    {
        return this.mod(rhs, max(this.scale, rhs.scale));
    }

    unittest
    {
        assert(DCNum(10) % DCNum(3) == 1);
        assert(DCNum(-10) % DCNum(3) == -1);
        assert(DCNum(10) % DCNum(-3) == 1);
        assert(DCNum(10) % DCNum("3.0") == DCNum("0.1"));
        assert(DCNum(10) % DCNum("3.000") == DCNum("0.001"));
    }

    /// Find square root by Newton's algorithm
    /// this function assumes this >= 0
    /// the returned value has specified scale
    DCNum sqrt(uint scale) const pure
    {
        // check this
        if (DCNum.cmp(this, DCNum(0)) <= 0)
        {
            throw new DCNumException("negative or zero value given for sqrt");
        }

        // guess the start value
        DCNum guess;
        final switch (DCNum.cmp(this, DCNum(1)))
        {
        case 0:
            return DCNum(1).rescaled(scale);
        case -1:
            guess = DCNum(1);
            break;
        case 1:
            guess = DCNum(cast(ubyte[])([1]) ~ new ubyte[](this.len / 2));
            break;
        }

        // newton's algorithm
        while (true)
        {
            // update guess
            DCNum new_guess = (this.div(guess, scale + 1) + guess).mul(DCNum("0.5"), scale);
            DCNum diff = new_guess - guess;
            guess = DCNum(new_guess);
            // check diff is near the zero
            if (diff.value[0 .. $ - 1].all!"a == 0" && diff.value[$ - 1] <= 0)
            {
                break;
            }
        }

        guess.rescale(scale);
        return guess;
    }

    unittest
    {
        assertThrown!DCNumException(DCNum(0).sqrt(1));
        assertThrown!DCNumException(DCNum(-4).sqrt(1));

        assert(DCNum(2).sqrt(0) == DCNum("1"));
        assert(DCNum(2).sqrt(1) == DCNum("1.4"));
        assert(DCNum(2).sqrt(5) == DCNum("1.41421"));
        assert(DCNum(2).sqrt(10) == DCNum("1.4142135623"));

        assert(DCNum(4).sqrt(0) == DCNum("2"));
        assert(DCNum(16).sqrt(1) == DCNum("4.0"));
        assert(DCNum("9.99").sqrt(5) == DCNum("3.16069"));
        assert(DCNum("33333333333333333333333333").sqrt(10) == DCNum("5773502691896.2576450914"));
    }

    /// raise this to the exponent power
    DCNum raise(long exponent, uint scale) pure const
    {
        if (exponent == 0)
        {
            return DCNum(1);
        }

        bool neg;
        if (exponent < 0)
        {
            neg = true;
            exponent = -exponent;
        }
        else
        {
            neg = false;
            scale = min(this.scale * exponent, max(this.scale, scale)).to!uint;
        }

        DCNum pow = DCNum(this);
        uint pow_scale = this.scale;
        while ((exponent & 1) == 0)
        {
            pow_scale <<= 1;
            pow = pow.mul(pow, pow_scale);
            exponent >>= 1;
        }

        DCNum result = DCNum(pow);
        uint calc_scale = pow_scale;
        exponent >>= 1;
        while (exponent > 0)
        {
            pow_scale <<= 1;
            pow = pow.mul(pow, pow_scale);
            if (exponent & 1)
            {
                calc_scale += pow_scale;
                result = result.mul(pow, calc_scale);
            }
            exponent >>= 1;
        }

        if (neg)
        {
            return DCNum(1).div(result, scale);
        }
        else
        {
            return result.rescaled(scale);
        }
    }

    unittest
    {
        import std.stdio;

        assert(DCNum(2).raise(3, 0) == DCNum(8));
        assert(DCNum("5.0").raise(4, 0) == DCNum("625.0"));
        assert(DCNum("1.234").raise(5, 0) == DCNum("2.861"));
        assert(DCNum("1.234").raise(5, 10) == DCNum("2.8613817210"));
        assert(DCNum("1.234").raise(5, 20) == DCNum("2.861381721051424"));

        assert(DCNum(2).raise(-3, 0) == DCNum("0"));
        assert(DCNum(2).raise(-3, 1) == DCNum("0.1"));
        assert(DCNum(2).raise(-3, 5) == DCNum("0.12500"));
        assert(DCNum("5.0000000").raise(-4, 0) == DCNum("0"));
        assert(DCNum("5.0000000").raise(-4, 10) == DCNum("0.0016000000"));
    }
}
