"resource/screens/vgui_mortar_screen.res"
{
	"mortar_control_screen"
	{
		"ControlName"	"EditablePanel"
		"fieldName"		"mortar_control_screen"
		"xpos"			"0"
		"ypos"			"0"
		"wide"			"480"
		"tall"			"620"
		"autoResize"	"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"	"0"
		"acceptsinput" 	"1"
	}
	
	"FireButton"
	{
		"ControlName"	"MortarControlButton"
		"fieldName"		"FireButton"
		"xpos"			"190"
		"ypos"			"555"
		"wide"			"100"
		"tall"			"60"
		"autoResize"	"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"	"0"
		"labelText"		"FIRE"
		"textAlignment"	"center"
		"dulltext"		"0"
		"brighttext"	"1"
		"wrap"			"0"
		"centerwrap"	"0"
		"textinsetx"	"6"
		"textinsety"	"0"
		"command"		"FireMortar"
		"font"			"MortarButtonLarge"
		
		"enabledImage"
		{
			"material"	"vgui/screens/vgui_button_enabled"
			"color" "255 255 255 255"
		}

		"mouseOverImage"
		{
			"material"	"vgui/screens/vgui_button_hover"
			"color" "255 255 255 255"
		}

		"pressedImage"
		{
			"material"	"vgui/screens/vgui_button_pushed"
			"color" "255 255 255 255"
		}

		"disabledImage"
		{
			"material"	"vgui/screens/vgui_button_disabled"
			"color" "255 255 255 255"
		}
	}
}
