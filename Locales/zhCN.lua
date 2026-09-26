if GetLocale() ~= "zhCN" then
	return
end

local _, ns = ...
local L = ns.L

L["next_reset_dropdown_exclude_types"] = "排除世界任务类型"
L["next_reset_dropdown_exclude_maps"] = "排除地图"
L["next_reset_button_text"] = "下次重置：%s（%d）"
L["next_reset_tooltip_title"] = "世界任务即将重置"
L["next_reset_tooltip_quest_num"] = "任务数量：|cnWHITE_FONT_COLOR:%d|r"
L["characters_dropdown_title"] = "排除角色"
L["characters_dropdown_instruction"] = "按下 %s 删除角色"
L["characters_tooltip_title"] = "已追踪角色状态"
L["characters_tooltip_last_reset_time"] = "上次世界任务重置时间：|cnWHITE_FONT_COLOR:%s|r"
L["warmode_tooltip_instruction"] = "点击以%s战争模式按钮"
L["settings_pins_section_all"] = "应用到所有图标"
L["settings_pins_section_filtered"] = "仅筛选后任务的图标"
L["settings_pins_progress_label_shown_text"] = "战团进度标签"
L["settings_pins_progress_label_shown_tooltip"] =
	"在提供筛选奖励的任务图标上显示进度文字|n|n可在|cnWHITE_FONT_COLOR:任务日志|r设置中调整文字格式"
L["settings_pins_inactive_opacity_text"] = "未激活任务透明度"
L["settings_pins_inactive_opacity_tooltip"] = "调整透明度，隐藏或淡化未激活任务的图标"
L["settings_pins_tooltip_progress_shown_text"] = "提示框内显示进度"
L["settings_pins_tooltip_progress_shown_tooltip"] = "在地图图标提示框中显示所有追踪角色的任务进度与奖励"
L["settings_pins_continent_maps_shown_text"] = "大陆地图"
L["settings_pins_continent_maps_shown_tooltip"] = "在大陆地图上显示任务图标"
L["settings_pins_completed_quest_shown_text"] = "已完成任务"
L["settings_pins_completed_quest_shown_tooltip"] = "显示已完成任务图标，并附带 |A:common-icon-checkmark:15:15:0:0|a 标记"
L["settings_log_all_quests_shown_text"] = "显示全部任务"
L["settings_log_all_quests_shown_tooltip"] = "展示所有扫描地图中的任务|n|n关闭后，仅显示当前地图任务"
L["settings_log_default_tab_text"] = "默认标签页"
L["settings_log_default_tab_tooltip"] = "将 %s 设为默认标签页，登录后首次打开世界地图时自动打开"
L["settings_log_section_fields"] = "任务信息字段"
L["settings_log_scanning_icon_shown_text"] = "待扫描图标"
L["settings_log_scanning_icon_shown_tooltip"] = "若尚未在全部追踪角色上扫描该任务进度，则在任务标题处显示图标 %s"
L["settings_log_progress_shown_text"] = "战团进度"
L["settings_log_progress_shown_tooltip"] =
	"显示进度标签，标识所有角色的任务完成状态|n|n|cnWHITE_FONT_COLOR:红色文字|r|n当前角色无法从该任务获取筛选奖励|n|n|cnWHITE_FONT_COLOR:绿色文字|r|n当前角色已完成此任务。"
L["settings_log_progress_shown_option_1_text"] = "已领取奖励角色"
L["settings_log_progress_shown_option_1_tooltip"] =
	"以 |cnWHITE_FONT_COLOR:X/Y|r 形式展示进度|n|n|cnWHITE_FONT_COLOR:X|r|n已完成任务并领取筛选奖励的角色数量|n|n|cnWHITE_FONT_COLOR:Y|r|n有资格领取该任务筛选奖励的角色总数"
L["settings_log_progress_shown_option_2_text"] = "剩余角色"
L["settings_log_progress_shown_option_2_tooltip"] =
	"显示有资格领取任务筛选奖励、但尚未完成任务的角色数量"
L["settings_log_time_left_shown_tooltip"] = "在任务日志中显示剩余时间标签"
L["settings_log_warband_rewards_shown_tooltip"] =
	"在任务日志内展示全角色累计奖励，可选择显示总和或未领取部分。|n关闭后，仅显示当前登录角色的奖励"
L["settings_maps_title"] = "扫描地图"
L["settings_filters_title"] = "按奖励筛选任务"
L["settings_section_text"] = "%s 分组"
L["settings_section_completed_tooltip"] = "在【已完成】分组下显示已完成任务|n|n关闭后，已完成任务将归入【未激活】分组"
L["settings_section_completed_option_all_text"] = "全部符合条件角色"
L["settings_section_completed_option_all_tooltip"] = "只有所有角色都领取筛选奖励后，任务才判定为已完成"
L["settings_section_completed_option_current_text"] = "仅当前角色"
L["settings_section_completed_option_current_tooltip"] = "当前角色完成任务即判定任务为已完成"
L["log_entry_tooltip_characters"] = "角色："
L["log_entry_tooltip_characters_scanned"] = "已扫描"
L["log_entry_tooltip_total_rewards"] = "战团总奖励："
