local C = {
    cookies = { stage1=false, stage2=false, stage3=false, stage4=false },
    pets    = 0,   -- times the cat has been petted this run
}

function C.collect(stage)  C.cookies[stage] = true end

function C.pet() C.pets = C.pets + 1 end

function C.reset()
    for k in pairs(C.cookies) do C.cookies[k] = false end
    C.pets = 0
end

function C.count()
    local n = 0
    for _, v in pairs(C.cookies) do if v then n = n + 1 end end
    return n
end

function C.allCollected()
    for _, v in pairs(C.cookies) do if not v then return false end end
    return true
end

return C
