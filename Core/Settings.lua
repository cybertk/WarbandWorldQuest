local _, namespace = ...

local Settings = { callbacks = {}, keysMonitored = {} }

function Settings:RegisterSettings(savedVariableName, default)
	if _G[savedVariableName] == nil then
		_G[savedVariableName] = {}
	end

	self.settings = _G[savedVariableName]

	for key, value in pairs(default) do
		if self.settings[key] == nil then
			self.settings[key] = value
		end
	end
end

function Settings:RegisterCallback(keyPattern, callback, owner, ...)
	if self.callbacks[keyPattern] == nil then
		self.callbacks[keyPattern] = {}
	end

	self.callbacks[keyPattern][owner] = GenerateClosure(callback, owner, ...)

	for key, _ in pairs(self.keysMonitored) do
		if key:find(keyPattern) then
			self.keysMonitored[key] = nil
		end
	end
end

function Settings:InvokeAndRegisterCallback(keyPattern, callback, ...)
	callback(..., self.settings[keyPattern], keyPattern)
	self:RegisterCallback(keyPattern, callback, ...)
end

function Settings:UnregisterCallback(keyPattern, owner)
	if self.callbacks[keyPattern] == nil then
		return
	end

	self.callbacks[keyPattern][owner] = nil
end

function Settings:Notify(key, value)
	if self.keysMonitored[key] == nil then
		local callbacks = {}

		for pattern, closures in pairs(self.callbacks) do
			if key:find(pattern) then
				for _, closure in pairs(closures) do
					table.insert(callbacks, closure)
				end
			end
		end

		self.keysMonitored[key] = callbacks
	end

	for _, callback in ipairs(self.keysMonitored[key]) do
		callback(value, key)
	end
end

function Settings:Set(key, value)
	local oldValue = self.settings[key]
	if oldValue == value then
		return
	end

	if type(value) == "table" then
		Mixin(self.settings[key], value)
	else
		self.settings[key] = value
	end

	self:Notify(key, value)
end

function Settings:Get(key)
	return self.settings[key]
end

function Settings:Toggle(key)
	self:Set(key, not self.settings[key])
end

function Settings:GenerateGetter(key)
	return GenerateClosure(self.Get, self, key)
end

function Settings:GenerateTableGetter(key)
	return function(tableIndex)
		return self.settings[key][tableIndex]
	end
end

function Settings:GenerateComparator(key, value)
	return function(overrideValue)
		return self.settings[key] == (overrideValue or value)
	end
end

function Settings:GenerateSetter(key)
	return GenerateClosure(self.Set, self, key)
end

function Settings:GenerateToggler(key)
	return GenerateClosure(self.Toggle, self, key)
end

function Settings:GenerateTableToggler(key)
	return function(tableIndex)
		self:Set(key, { [tableIndex] = not self.settings[key][tableIndex] })
	end
end

function Settings:GenerateRotator(key, values)
	return function(overrideValues)
		local index = 1
		for i, v in ipairs(overrideValues or values) do
			if v == self.settings[key] then
				index = i
				break
			end
		end

		index = index == #values and 1 or (index + 1)

		self:Set(key, values[index])
	end
end

function Settings:CreateCheckboxMenu(key, menu, text, tableIndex)
	if tableIndex then
		return menu:CreateCheckbox(text, Settings:GenerateTableGetter(key), Settings:GenerateTableToggler(key), tableIndex)
	else
		return menu:CreateCheckbox(text, Settings:GenerateGetter(key), Settings:GenerateToggler(key))
	end
end

function Settings:CreateRadio(key, menu, text, data)
	return menu:CreateRadio(text, Settings:GenerateComparator(key), Settings:GenerateSetter(key), data)
end

namespace.Settings = Settings
