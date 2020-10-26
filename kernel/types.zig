
pub const Point = struct {
    x:usize = 0,
    y:usize = 0,
};

pub const Size = struct {
    width:usize = 0,
    height:usize = 0,
};

pub const Rectangle = struct {
    top:usize = 0,
    left:usize = 0,
    bottom:usize = 0,
    right:usize = 0,

    pub fn Width(self:*const Rectangle) usize {
        return self.right - self.left;
    }

    pub fn Height(self:*const Rectangle) usize {
        return self.bottom - self.top;
    }
};

