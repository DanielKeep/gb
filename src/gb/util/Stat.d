/**
 * Implements some statistical functions.
 *
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.util.Stat;

import tango.math.Math : sqrt;
import tango.math.Probability : studentsTDistributionInv;

/**
 * This structure provides a very simple interface for collecting statistics
 * on a sequence of values.
 *
 * To use, just use the concatenate-assign operator (~=) to add values to the
 * collection.
 */
struct Stat
{
    /**
     * Computes the minimum.
     */
    double min()
    {
        if( _min == _min )
            return _min;

        double r;
        foreach( v ; vs )
            if( v < r || r != r )
                r = v;

        _min = r;
        return _min;
    }

    private double _min;
    
    /**
     * Computes the maximum.
     */
    double max()
    {
        if( _max == _max )
            return _max;

        double r;
        foreach( v ; vs )
            if( v > r || r != r )
                r = v;

        _max = r;
        return _max;
    }

    private double _max;

    /**
     * Computes the mean.
     */
    double mean()
    {
        if( _mean == _mean )
            return _mean;

        real acc = 0.0;
        foreach( v ; vs )
            acc += v;

        _mean = acc/vs.length;
        return _mean;
    }

    alias mean μ;           /// ditto

    private double _mean;

    /**
     * Computes the standard deviation.
     */
    double stddev()
    {
        auto μ = this.μ;
        real acc = 0.0;
        foreach( v ; vs )
        {
            real dev = (μ - v);
            acc += dev*dev;
        }

        _stddev = sqrt(acc/(vs.length-1));
        return _stddev;
    }

    alias stddev σ; /// ditto

    private double _stddev;

    /**
     * Computes how many standard deviations from the mean a confidence
     * interval must extend in order to get a specified level of confidence.
     */

    double stddevConf(double confidence)
    {
        auto n = vs.length;
        auto ν = n-1;
        auto t = (1.0+confidence)/2.0;
        auto A = studentsTDistributionInv(ν, t);
        auto r = A / sqrt(cast(real)n);
        return r;
    }

    /**
     * Returns Δ such that:
     *
     *      [μ - Δ, μ + Δ]
     *
     * represents a confidence interval with the specified confidence.
     */

    double confDev(double confidence)
    {
        auto σ_m = σ * stddevConf(confidence);
        return σ_m;
    }

    /**
     * Adds a value to the collection.
     */
    double opCatAssign(double v)
    {
        vs ~= v;
        _min = _max = _mean = _stddev = double.nan;
        return v;
    }

    private double[] vs;
}

