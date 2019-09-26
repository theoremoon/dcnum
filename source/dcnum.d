module dcnum;

import std.traits : isIntegral;
import std.conv : to;
import std.math : log10;
import std.format : format;
import std.array : join;
import std.algorithm : reverse, min, max, all, map;
import std.exception;

const BASE = 10;

class DCNumException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

struct DCNum
{
private:
    bool sign; // when true this value is negative;
    uint len; // number of digits before the decimal point.
    uint scale; // number of digits after the decimal point.
    ubyte[] value; // array of digits. from higher digit to lower digit.

    this(T, U)(bool sign, T len, U scale, in ubyte[] value) pure 
            if (isIntegral!T && isIntegral!U)
    {
        this.sign = sign;
        this.len = len.to!uint;
        this.scale = scale.to!uint;
        this.value = value.dup;
    }

public:
    /// constructor from Integral values
    this(INT)(INT val) if (isIntegral!INT)
    {

        // zero is special case
        if (val == 0)
        {
            this.sign = false;
            this.value = [0];
            this.len = 1;
            this.scale = 0;
            return;
        }

        if (val < 0)
        {
            this.sign = true;
            val = -val;
        }
        else
        {
            this.sign = false;
        }

        uint index = 0;
        ubyte[] buf = new ubyte[](cast(uint) log10(INT.max));
        while (val != 0)
        {
            buf[index++] = cast(ubyte)(val % BASE);
            val = val / BASE;
        }

        this.value = reverse(buf[0 .. index]);
        this.len = cast(uint) index;
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
    this(string value)
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
        this.len = 0;
        this.scale = 0;
        while (value.length > p)
        {
            if ('0' <= value[p] && value[p] <= '9')
            {
                this.value[index++] = cast(ubyte)(value[p] - '0');
                p++;
                this.len++;
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
        this.value.length = (this.len + this.scale);

        // zero
        if (this.len == 0 && this.scale == 0)
        {
            this.sign = false;
            this.len = 1;
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

    string toString() const
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
            s ~= this.value[0 .. this.len].map!(to!string).join("");
        }

        if (this.scale > 0)
        {
            s ~= ".";
            s ~= this.value[this.len .. this.len + this.scale].map!(to!string).join("");
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

    bool isZero() pure const
    {
        return this.value == [0];
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
        assert(DCNum("0.1") < DCNum("0.101"));
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
            buf[i] = cast(ubyte)(lhs_value[i] + rhs_value[i] + carry);
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
        uint new_len = max(lhs.len, rhs.len);
        if (carry)
        {
            buf = cast(ubyte[])[1] ~ buf;
            new_len += 1;
        }
        return DCNum(false, new_len, new_scale, buf);
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
        uint new_len = lhs.len;

        // shrink value
        uint p = 0;
        while (p < new_len && lhs_value[p] == 0)
        {
            p++;
        }
        lhs_value = lhs_value[p .. $];
        new_len -= p;

        return DCNum(false, new_len, new_scale, lhs_value);
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
    /// this function ignores sign and scale, caller should set len and scale ownselfe
    private static DCNum mul(in DCNum lhs, in DCNum rhs) pure
    {
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
            const lhs_low = DCNum(false, lhs.value.length - half_len, 0, lhs.value[half_len .. $]);
            const lhs_high = DCNum(false, half_len, 0, lhs.value[0 .. half_len]);

            // high * rhs  || low * rhs
            const low_result = DCNum.mul(lhs_low, rhs);
            const high_result = DCNum.mul(lhs_high, rhs);
            const high_value = high_result.value ~ new ubyte[](lhs.value.length - half_len);
            return DCNum(false, high_value.length, 0, high_value) + low_result;
        }
        if (rhs_size > max_base_size)
        {
            // split rhs = high || low
            const half_len = (rhs.len + rhs.scale) / 2;
            const rhs_low = DCNum(false, rhs.value.length - half_len, 0, rhs.value[half_len .. $]);
            const rhs_high = DCNum(false, half_len, 0, rhs.value[0 .. half_len]);

            // high * lhs  || low * lhs
            const low_result = DCNum.mul(rhs_low, lhs);
            const high_result = DCNum.mul(rhs_high, lhs);
            const high_value = high_result.value ~ new ubyte[](rhs.value.length - half_len);
            return DCNum(false, high_value.length, 0, high_value) + low_result;
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
            return DCNum(false, 0, 0, buf);
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
        const v0 = DCNum(false, cast(int) buf0.length, 0, buf0);
        const v1 = DCNum(false, cast(int) buf1.length, 0, buf1);
        const v2 = DCNum(false, cast(int) buf2.length, 0, buf2); // summing
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

    DCNum opBinary(string op : "*")(in DCNum rhs) const pure
    {
        if (this.isZero || rhs.isZero)
        {
            return DCNum(0);
        }

        auto v = DCNum.mul(this, rhs);
        v.scale = this.scale + rhs.scale;
        if (v.value.length < v.scale)
        {
            v.value = new ubyte[](v.scale - v.value.length) ~ v.value;
        }
        v.len = to!uint(v.value.length - v.scale);
        if (this.sign != rhs.sign)
        {
            v.sign = true;
        }
        return v;
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

}
