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

    this(bool sign, uint len, uint scale, ubyte[] value)
    {
        this.sign = sign;
        this.len = len;
        this.scale = scale;
        this.value = value;
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

    /// if this is larger than rhs, return 1. smaller than rhs, then return -1. if this and rhs are same, return 0;
    private int cmp(in DCNum rhs, bool ignore_sign = false) pure const
    {
        // compare sign
        if (this.sign == false && rhs.sign == true && ignore_sign == false)
        {
            return 1;
        }
        else if (this.sign == true && rhs.sign == false && ignore_sign == false)
        {
            return -1;
        }
        int sign = (this.sign && ignore_sign == false) ? -1 : 1;

        // compare size of integer part
        if (this.len > rhs.len)
        {
            return sign;
        }
        else if (this.len < rhs.len)
        {
            return -sign;
        }

        // compare integer parts
        foreach (i; 0 .. this.len)
        {
            if (this.value[i] > rhs.value[i])
            {
                return sign;
            }
            else if (this.value[i] < rhs.value[i])
            {
                return -sign;
            }
        }

        // compare fraction parts
        foreach (i; 0 .. min(this.scale, rhs.scale))
        {
            if (this.value[this.len + i] > rhs.value[rhs.len + i])
            {
                return sign;
            }
            else if (this.value[this.len + i] < rhs.value[rhs.len + i])
            {
                return -sign;
            }
        }

        if (this.scale > rhs.scale)
        {
            if (this.value[(this.len + rhs.scale) .. $].all!"a == 0")
            {
                return 0;
            }
            return sign;
        }
        else
        {
            if (rhs.value[(rhs.len + this.scale) .. $].all!"a == 0")
            {
                return 0;
            }
            return -sign;
        }
    }

    bool opEquals(in DCNum rhs) const pure
    {
        return this.cmp(rhs) == 0;
    }

    int opCmp(in DCNum rhs) const pure
    {
        return this.cmp(rhs);
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

    /// add this and rhs
    /// this function ignore sign
    private DCNum add(DCNum rhs)
    {
        ubyte[] this_value = this.value;
        ubyte[] rhs_value = rhs.value;

        // align digits before the decimal point
        if (this.len > rhs.len)
        {
            rhs_value = new ubyte[](this.len - rhs.len) ~ rhs_value;
        }
        else if (this.len < rhs.len)
        {
            this_value = new ubyte[](rhs.len - this.len) ~ this_value;
        }

        // align digits after the decimal point
        if (this.scale > rhs.scale)
        {
            rhs_value = rhs_value ~ new ubyte[](this.scale - rhs.scale);
        }
        else if (this.scale < rhs.scale)
        {
            this_value = this_value ~ new ubyte[](rhs.scale - this.scale);
        }

        // addition digit by digit
        ubyte carry = 0;
        ubyte[] buf = new ubyte[](this_value.length);
        foreach_reverse (i; 0 .. this_value.length)
        {
            buf[i] = cast(ubyte)(this_value[i] + rhs_value[i] + carry);
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

        const uint new_scale = max(this.scale, rhs.scale);
        uint new_len = max(this.len, rhs.len);
        if (carry)
        {
            buf = cast(ubyte[])[1] ~ buf;
            new_len += 1;
        }
        return DCNum(false, new_len, new_scale, buf);
    }

    /// subtract rhs from this. this must be larger than rhs on magnitude
    private DCNum sub(DCNum rhs)
    {
        ubyte[] this_value = this.value;

        // align digits after the decimal point
        if (this.scale < rhs.scale)
        {
            this_value = this_value ~ new ubyte[](rhs.scale - this.scale);
        }

        ubyte borrow = 0;
        const pad = this.len - rhs.len;
        foreach_reverse (i; 0 .. (rhs.len + rhs.scale))
        {
            if (this_value[pad + i] < rhs.value[i] + borrow)
            {
                this_value[pad + i] = cast(ubyte)((10 + this_value[pad + i]) - (
                        rhs.value[i] + borrow));
                borrow = 1;
            }
            else
            {
                this_value[pad + i] = cast(ubyte)(this_value[pad + i] - (rhs.value[i] + borrow));
                borrow = 0;
            }
        }
        if (borrow)
        {
            this_value[pad - 1]--;
        }

        uint new_scale = max(this.scale, rhs.scale);
        uint new_len = this.len;

        // shrink value
        uint p = 0;
        while (p < new_len && this_value[p] == 0)
        {
            p++;
        }
        this_value = this_value[p .. $];
        new_len -= p;

        return DCNum(false, new_len, new_scale, this_value);
    }

    DCNum opBinary(string op : "+")(DCNum rhs)
    {
        if (this.sign == false && rhs.sign == false)
        {
            return this.add(rhs);
        }
        else if (this.sign == true && rhs.sign == true)
        {
            auto v = this.add(rhs);
            v.sign = true;
            return v;
        }
        else
        {
            switch (this.cmp(rhs, true))
            {
            case 0:
                return DCNum(0);
            case 1:
                auto v = this.sub(rhs);
                v.sign = this.sign;
                return v;
            case -1:
                auto v = rhs.sub(this);
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

    DCNum opBinary(string op : "-")(DCNum rhs)
    {
        if (this.sign == false && rhs.sign == true)
        {
            return this.add(rhs);
        }
        else if (this.sign == true && rhs.sign == false)
        {
            auto v = this.add(rhs);
            v.sign = true;
            return v;
        }
        else
        {
            switch (this.cmp(rhs, true))
            {
            case 0:
                return DCNum(0);
            case 1:
                auto v = this.sub(rhs);
                v.sign = this.sign;
                return v;
            case -1:
                auto v = rhs.sub(this);
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
}
