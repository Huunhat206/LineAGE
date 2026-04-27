-- 1. Nhận biến Fluent và Window (cái khung GUI) từ GUI.lua truyền sang
local Fluent, Window = ...

-- 2. Lệnh này sẽ tạo ra cái Tab bên tay trái
local Tabs = {
    Farm = Window:AddTab({ Title = "Auto Farm", Icon = "swords" })
}

-- 3. Thêm thử một nút bấm vào trong Tab cho đỡ trống
Tabs.Farm:AddButton({
    Title = "Nút test thử",
    Description = "Nếu tab hiện lên và thấy nút này tức là đã thành công 100%!",
    Callback = function()
        print("Test Tab thành công!")
    end
})
