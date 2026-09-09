if GetLocale() ~= "koKR" then
	return
end

local _, ns = ...
local L = ns.L
L["next_reset_dropdown_exclude_types"] = "전역 퀘스트 종류 제외"
L["next_reset_dropdown_exclude_maps"] = "지도 제외"
L["next_reset_button_text"] = "다음 초기화: %s (%d)"
L["next_reset_tooltip_title"] = "다가오는 전역 퀘스트 초기화"
L["next_reset_tooltip_quest_num"] = "퀘스트 수: |cnWHITE_FONT_COLOR:%d|r"

L["characters_dropdown_title"] = "캐릭터 제외"
L["characters_dropdown_instruction"] = "%s 키를 눌러 캐릭터를 삭제하세요"
L["characters_tooltip_title"] = "추적 중인 캐릭터 상태"
L["characters_tooltip_last_reset_time"] = "마지막 전역 퀘스트 초기화 시간: |cnWHITE_FONT_COLOR:%s|r"

L["warmode_tooltip_instruction"] = "클릭하여 전쟁 모드 버튼을 %s"

L["settings_pins_section_all"] = "모든 핀에 적용"
L["settings_pins_section_filtered"] = "필터링된 퀘스트 핀만"
L["settings_pins_progress_label_shown_text"] = "전투부대 진행 상황 레이블"
L["settings_pins_progress_label_shown_tooltip"] =
	"필터링된 보상을 제공하는 퀘스트 핀에 진행 상황 텍스트를 표시합니다|n|n텍스트 형식은 |cnWHITE_FONT_COLOR:퀘스트 일지|r 설정에서 조정할 수 있습니다."
L["settings_pins_inactive_opacity_text"] = "비활성 퀘스트 투명도"
L["settings_pins_inactive_opacity_tooltip"] = "투명도를 조정하여 비활성 퀘스트의 핀을 숨기거나 흐리게 만듭니다"
L["settings_pins_tooltip_progress_shown_text"] = "툴팁에 진행 상황 표시"
L["settings_pins_tooltip_progress_shown_tooltip"] = "지도 핀의 툴팁에 추적 중인 모든 캐릭터의 퀘스트 진행 상황과 보상을 표시합니다"
L["settings_pins_continent_maps_shown_text"] = "대륙 지도"
L["settings_pins_continent_maps_shown_tooltip"] = "대륙 지도에 퀘스트 핀 표시"
L["settings_pins_completed_quest_shown_text"] = "완료한 퀘스트"
L["settings_pins_completed_quest_shown_tooltip"] = "완료한 퀘스트 핀을 |A:common-icon-checkmark:15:15:0:0|a 표시와 함께 표시합니다"
L["settings_log_all_quests_shown_text"] = "모든 퀘스트 표시"
L["settings_log_all_quests_shown_tooltip"] =
	"모든 탐색 지도에서 퀘스트를 표시합니다|n|n비활성화하면 현재 지도에 있는 퀘스트만 표시됩니다"
L["settings_log_default_tab_text"] = "기본 탭"
L["settings_log_default_tab_tooltip"] = "%s을(를) 기본 탭으로 설정합니다. 로그인 후 세계 지도를 처음 열 때 자동으로 열립니다."
L["settings_log_section_fields"] = "퀘스트 정보 필드"
L["settings_log_scanning_icon_shown_text"] = "대기 중인 스캔 아이콘"
L["settings_log_scanning_icon_shown_tooltip"] =
	"추적 중인 모든 캐릭터에서 퀘스트 진행 상황이 스캔되지 않은 경우 퀘스트 제목에 %s 아이콘을 표시합니다"
L["settings_log_progress_shown_text"] = "전투부대 진행 상황"
L["settings_log_progress_shown_tooltip"] =
	"캐릭터 간 퀘스트 완료 상태를 나타내는 진행 상황 레이블을 표시합니다|n|n|cnWHITE_FONT_COLOR:빨간색 텍스트|r|n현재 캐릭터에게 필터링된 보상을 제공하지 않는 퀘스트입니다|n|n|cnWHITE_FONT_COLOR:초록색 텍스트|r|n현재 캐릭터가 완료한 퀘스트입니다."
L["settings_log_progress_shown_option_1_text"] = "보상을 획득한 캐릭터"
L["settings_log_progress_shown_option_1_tooltip"] =
	"진행 상황을 |cnWHITE_FONT_COLOR:X/Y|r로 표시합니다|n|n|cnWHITE_FONT_COLOR:X|r|n퀘스트를 완료하고 필터링된 보상을 획득한 캐릭터 수|n|n|cnWHITE_FONT_COLOR:Y|r|n해당 퀘스트에서 필터링된 보상을 획득할 자격이 있는 캐릭터 수"
L["settings_log_progress_shown_option_2_text"] = "남은 캐릭터"
L["settings_log_progress_shown_option_2_tooltip"] = "필터링된 보상을 획득할 자격이 있지만 아직 완료하지 않은 캐릭터의 수를 표시합니다"
L["settings_log_time_left_shown_tooltip"] = "퀘스트 일지에 남은 시간 레이블을 표시합니다"
L["settings_log_warband_rewards_shown_tooltip"] =
	"퀘스트 일지에 모든 캐릭터의 누적 보상을 총합 또는 미수령 상태로 표시합니다.|n비활성화하면 현재 접속 중인 캐릭터의 보상을 표시합니다."
L["settings_maps_title"] = "탐색 지도"
L["settings_filters_title"] = "보상별 퀘스트 필터"
L["settings_section_text"] = "%s 섹션"
L["settings_section_completed_tooltip"] =
	"완료된 퀘스트 섹션 아래에 완료된 퀘스트를 표시합니다|n|n비활성화하면 완료된 퀘스트가 비활성 섹션 아래에 표시됩니다"
L["settings_section_completed_option_all_text"] = "모든 자격 요건 캐릭터"
L["settings_section_completed_option_all_tooltip"] = "모든 캐릭터가 필터링된 보상을 획득해야 퀘스트가 완료된 것으로 간주됩니다"
L["settings_section_completed_option_current_text"] = "현재 캐릭터만"
L["settings_section_completed_option_current_tooltip"] = "현재 캐릭터가 완료한 경우 퀘스트가 완료된 것으로 간주됩니다"

L["log_entry_tooltip_characters"] = "캐릭터:"
L["log_entry_tooltip_characters_scanned"] = "스캔한"
L["log_entry_tooltip_total_rewards"] = "총 전투부대 보상:"
