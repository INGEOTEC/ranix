import Base:
    getindex, push!, close, flush

type DiskWriter
    offset::IOStream
    data::IOStream
end

function DiskWriter(filename)
    DiskWriter(open(filename * ".offset", "a"), open(filename, "a"))
end

function push!(db::DiskWriter, d::String)
    write(db.data, d)
    write(db.offset, position(db.data))
end

function flush(db::DiskWriter)
    flush(db.data)
    flush(db.offset)
end

function close(db::DiskWriter)
    close(db.data)
    close(db.offset)
end

type JsonDiskReader
    offset::Vector{Int}
    data::Vector{UInt8}
end

function DiskReader(filename)
    JsonDiskReader(Mmap.mmap(filename * ".offset", Vector{Int}), Mmap.mmap(filename, Vector{UInt8}))
end

function getindex(r::JsonDiskReader, i)::String
    off = i == 1 ? 1 : r.offset[i - 1]
    s = r.data[off:r.offset[i]]
    String(s)
end

function getindex(r::JsonDiskReader, indexes...)
    [getindex(r, i) for i in indexes]
end
