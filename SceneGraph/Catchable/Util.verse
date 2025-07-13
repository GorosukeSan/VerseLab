
(InMap:[t]u).RemoveKey(TargetKey:t where t:subtype(comparable), u:type):[t]u=
    var Result:[t]u = map{}
    for:
        Key -> Value : InMap
        Key <> TargetKey
    do:
        ConcatenateMaps(Result, map{Key => Value})
    Result