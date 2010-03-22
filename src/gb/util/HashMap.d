/**
 * Fast, safe HashMap implementation.
 *
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.util.HashMap;

import gb.util.impl.HashMap : HashMapHeader;
public import gb.util.impl.HashMap : HashMapException;

/* This is used to control whether hashmaps are compared based on their
 * contents or merely the internal pointer.  Comparing pointers was the
 * default behaviour prior to DMD 1.057; HashMap defaults to the new
 * behaviour.
 */

version( HashMap_Compare_Contents )
    version = _HashMap_Compare_Contents;
else version( HashMap_Compare_Reference )
    version = _HashMap_Compare_Reference;
else
    version = _HashMap_Compare_Contents;

/**
 * A hash map which should function as a largely drop-in replacement for the
 * built-in associative array.
 *
 * HashMaps do not need to new'ed or explicitly initialised before use.  They
 * are reference types; if you wish to create a copy of a HashMap, use the dup
 * method.
 */
struct HashMap(Key, Value)
{
    /**
     * Destroys the contents of the HashMap and frees all associated storage
     * memory.
     */
    void clear()
    {
        if( ptr !is null )
        {
            ptr.clear();
        }
    }

    /**
     * Creates an independent copy of this HashMap and returns it.
     */
    HashMap dup()
    {
        HashMap r;
        r.ensure_exists;
        this.ptr.copyTo(*(r.ptr));
        return r;
    }

    /**
     * Attempts to remove the specified key from the HashMap.  Throws an
     * HashMapException if the key is not defined in the map.
     *
     * To perform a non-throwing remove, see tryRemove.
     */
    void remove(Key key)
    {
        if( ptr is null || !ptr.remove(key) )
            HashMapException.throw_removeMissing;
    }

    /**
     * Attempts to remove the specified key from the HashMap.  Returns true if
     * the key was removed, false if the key was not defined in the map.
     */
    bool tryRemove(Key key)
    {
        if( ptr is null )
            return false;
        return ptr.remove(key);
    }

    /**
     * Returns the number of entries stored in the map.
     */
    size_t length()
    {
        if( ptr is null ) return 0;
        return ptr.entries;
    }
    
    /**
     * Returns an array containing all keys defined in the map.  These keys
     * are not returned in any particular order.  The array is safe to mutate,
     * although you should not mutate the keys themselves if they are, or
     * contain, references.
     */
    Key[] keys()
    {
        if( ptr is null )
            return null;

        return ptr.keysToArray;
    }

    /**
     * Returns an array containing all values defined in the map.  These
     * values are not returned in any particular order.  The array is safe to
     * mutate, although you should not mutate the keys themselves if they are,
     * or contain, references.
     */
    Value[] values()
    {
        if( ptr is null )
            return null;

        return ptr.valuesToArray;
    }

    /**
     * Provided for compatibility with the builtin AA type.  Does not actually
     * do anything.
     */
    HashMap rehash()
    {
        // TODO: determine if this should actually do anything.
        // I suspect that it won't actually make any
        // difference; it might permute the order of elements, but probably
        // won't improve performance any.
        return *this;
    }

    private
    {
        int iterKeysEmpty(int delegate(ref Key) dg) { return 0; }
        int iterValuesEmpty(int delegate(ref Value) dg) { return 0; }
        int iterItemsEmpty(int delegate(ref Key, ref Value) dg) { return 0; }
    }

    /**
     * Returns a delegate which can be used with foreach to iterate over the
     * keys of the map without additional allocations taking place.
     */
    int delegate(int delegate(ref Key)) iterKeys()
    {
        if( ptr is null )
            return &iterKeysEmpty;

        return &ptr.iterKeys;
    }

    /**
     * Returns a delegate which can be used with foreach to iterate over the
     * values of the map without additional allocations taking place.
     */
    int delegate(int delegate(ref Value)) iterValues()
    {
        if( ptr is null )
            return &iterValuesEmpty;

        return &ptr.iterValues;
    }

    /**
     * Returns a delegate which can be used with foreach to iterate over the
     * entries of the map without additional allocations taking place.
     */
    int delegate(int delegate(ref Key, ref Value)) iterItems()
    {
        if( ptr is null )
            return &iterItemsEmpty;

        return &ptr.iterItems;
    }
    
    /**
     * Iterates over the values of the map.
     */
    int opApply(int delegate(ref Value) dg)
    {
        if( ptr is null )
            return 0;

        return ptr.iterValues(dg);
    }

    /**
     * Iterates over the entries of the map.
     */
    int opApply(int delegate(ref Key, ref Value) dg)
    {
        if( ptr is null )
            return 0;

        return ptr.iterItems(dg);
    }

    /**
     * Compares two HashMaps for equality.
     *
     * By default, this will perform a full compare of the contents of the
     * map, which matches the behaviour of DMD 1.057 and later.  If you want
     * to use the pre-1.057 behaviour of only doing a pointer comparison,
     * compile with the version HashMap_Compare_Reference.
     */
    bool opEquals(HashMap rhs)
    {
        version( _HashMap_Compare_Contents )
        {
            // Some borderline cases.
            {
                if( this.ptr is rhs.ptr )
                    return true;

                if( this.ptr is null || rhs.ptr is null )
                    return false;
            }

            // To do this, we need to check two things:
            // 1. both hashmaps have the exact same number of entries, and
            // 2. each key in this exists in and has the same associated value
            //    in the other.

            if( this.length != rhs.length )
                return false;

            foreach( ref k, ref v ; *this )
            {
                auto rhsv = k in rhs;
                if( rhsv is null || v != *rhsv )
                    return false;
            }
            
            return true;
        }
        else version( _HashMap_Compare_Reference )
        {
            return (this.ptr is rhs.ptr);
        }
        else
            static assert(false);
    }

    /**
     * Determines if the given key is defined in the map.  If it is, it
     * returns a pointer to the associated value; if it is not, it returns
     * null.
     *
     * WARNING: unlike the builtin AA type, this method is extremely
     * dangerous: the returned pointer can be invalidated by inserting or
     * removing an entry.  The returned pointer should be used and discarded
     * immediately.
     *
     * A safe alternative is provided by the tryLookup method.
     */
    Value* opIn_r(Key key)
    {
        if( ptr is null )
            return null;

        return ptr.lookup(key);
    }

    /**
     * Retrieves the value associated with the given key.
     *
     * Throws a HashMapException if the key is not defined.
     *
     * To perform a non-throwing lookup, see tryLookup.
     */
    Value lookup(Key key)
    {
        auto vPtr = key in *this;
        if( vPtr is null )
            HashMapException.throw_keyMissing;

        return *vPtr;
    }

    /// ditto
    alias lookup opIndex;

    /**
     * Attempts to retrieve the value associated with the given key.  Returns
     * true if and only if the key was found.
     */
    bool tryLookup(Key key, out Value value)
    {
        auto vPtr = key in *this;
        if( vPtr !is null )
            value = *vPtr;

        return (vPtr !is null);
    }

    /**
     * Associates the key and value in the map.  If the key is already
     * defined, it will replace the existing association.
     */
    Value insert(Key key, Value value)
    {
        ensure_exists;

        ptr.insert(key, value);
        return value;
    }

    /// ditto
    Value opIndexAssign(Value value, Key key)
    {
        // Why not forward?  Redundant copying.
        // Why not use ref?  It breaks fucking everything.
        ensure_exists;

        ptr.insert(key, value);
        return value;
    }

    private typedef void* NullLiteral;

    /**
     * This allows you to assign 'null' to a HashMap to remove its reference
     * to the underlying data.  This does not free any memory unless a garbage
     * collection occurs and there are no other references to the data.
     *
     * To destroy the contents of a HashMap and free its memory, see the clear
     * method.
     */
    HashMap opAssign(NullLiteral n)
    {
        ptr = null;
        return *this;
    }

private:
    alias HashMapHeader!(Key, Value, hash_t) Header;
    Header* ptr = null;

    void ensure_exists()
    {
        if( ptr is null ) ptr = Header.create();
    }
}

