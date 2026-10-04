"Resource/LoadingDialog.res"
{
	// -------------------------------------------------------------
    // Main loading dialog panel attributes.
    // -------------------------------------------------------------
	"LoadingDialog"
	{
		"ControlName"	        "Frame"
		"fieldName"		        "LoadingDialog"
		"xpos"		            "0"
		"ypos"		            "0"
		"wide"		            "f"
		"tall"		            "f"
		"autoResize"	        "0"
		"pinCorner"		        "0"
		"visible"		        "1"
		"enabled"		        "1"
		"tabPosition"	        "0"
        "paintbackground"       "0"
        "setclosebuttonvisible" "0"
        "zpos"                  "0"
	}
    
    "BlackMesaLoadingDialogMapImage"
    {
        "ControlName"           "ImagePanel"
        "fieldName"             "BlackMesaLoadingDialogMapImage"
        "xpos"                  "0"
        "ypos"                  "0"
        "wide"                  "f"
        "tall"                  "f"
        "visible"               "0"
        "enabled"               "1"
        "scaleImage"            "1"
        "pinCorner"             "0"
        "paintbackground"       "1"
        "paintbackgroundtype"   "0"
        "zpos"                  "1"
    }
    
    // -------------------------------------------------------------
    // Header panel.
    // -------------------------------------------------------------
    "BlackMesaHeaderPanel"
    {
        "ControlName"           "Panel"
        "fieldName"             "BlackMesaHeaderPanel"
		"xpos"		            "0"
		"ypos"		            "0"
        "wide"		            "f"
		"tall"		            "50"
		"autoResize"	        "0"
		"pinCorner"		        "0"
		"visible"		        "1"
		"enabled"		        "1"
		"tabPosition"	        "0"
        "paintbackground"       "1"
        "setclosebuttonvisible" "0"
        "zpos"                  "2"
    }
    
    "BlackMesaLogo"
    {
        "ControlName"           "ImagePanel"
        "fieldName"             "BlackMesaLogo"
        "xpos"                  "10"
        "ypos"                  "0"
        "wide"                  "400"
        "tall"                  "50"
        "visible"               "1"
        "enabled"               "1"
        "image"                 "../logo/BM_Logo"
        "scaleImage"            "1"
        "pinCorner"             "0"
        "paintbackground"       "1"
        "paintbackgroundtype"   "0"
        "zpos"                  "3"
    }
    
    "BlackMesaLogoBorder"
    {
        "ControlName"           "Panel"
        "fieldName"             "BlackMesaLogoBorder"
        "xpos"                  "-5"
        "ypos"                  "50"
        "wide"                  "full"
        "tall"                  "2"
        "visible"               "1"
        "enabled"               "1"
        "paintbackground"       "1"
        "paintbackgroundtype"   "3"
        "bgcolor_override"      "Orange"
        "RoundedCorners"        "0"
        "zpos"                  "3"
    }

    // -------------------------------------------------------------
    // This is the footer border and background panel.
    // -------------------------------------------------------------
    "BlackMesaFooterBorder"
    {
        "ControlName"           "Panel"
        "fieldName"             "BlackMesaFooterBorder"
        "xpos"                  "-5"
        "ypos"                  "320"
        "wide"                  "f"
        "tall"                  "3"
        "visible"               "1"
        "enabled"               "1"
        "paintbackground"       "1"
        "paintbackgroundtype"   "3"
        "bgcolor_override"      "Orange"
        "zpos"                  "3"
    }
    
    "BlackMesaFooterPanel"
    {
        "ControlName"           "Panel"
        "fieldName"             "BlackMesaFooterPanel"
		"xpos"		            "0"
		"ypos"		            "323"
        "wide"		            "f"
		"tall"		            "f"
		"autoResize"	        "0"
		"pinCorner"		        "0"
		"visible"		        "1"
		"enabled"		        "1"
		"tabPosition"	        "0"
        "paintbackground"       "1"
        "setclosebuttonvisible" "0"
        "zpos"                  "3"
    }
    
    // -------------------------------------------------------------
    // Map information.
    // -------------------------------------------------------------
    "BlackMesaFooterMapNameLabel"
    {
        "ControlName"           "Label"
        "fieldName"             "BlackMesaFooterMapNameLabel"
        "xpos"                  "10"
        "ypos"                  "325"
        "wide"                  "300"
        "tall"                  "27"
        "visible"               "0"
        "enabled"               "1"
        "paintbackground"       "0"
        "paintbackgroundtype"   "0"
        "zpos"                  "3"
		"font"					"LoadingScreenMapName"
    }
    
    "BlackMesaFooterMapPlayerCountLabel"
    {
        "ControlName"           "Label"
        "fieldName"             "BlackMesaFooterMapPlayerCountLabel"
        "xpos"                  "11"
        "ypos"                  "352"
        "wide"                  "300"
        "tall"                  "10"
        "visible"               "0"
        "enabled"               "1"
        "paintbackground"       "0"
        "paintbackgroundtype"   "0"
        "zpos"                  "3"
		"font"					"LoadingScreenPlayerCount"
    }
    
    "BlackMesaFooterMapDescriptionLabel"
    {
        "ControlName"           "Label"
        "fieldName"             "BlackMesaFooterMapDescriptionLabel"
        "xpos"                  "10"
        "ypos"                  "371"
        "wide"                  "280"
        "tall"                  "f-371"
        "visible"               "0"
        "enabled"               "1"
        "paintbackground"       "0"
        "paintbackgroundtype"   "0"
        "zpos"                  "3"
		"textAlignment"			"north-west"
		"font"					"LoadingScreenMapDescription"
    }
    
    // -------------------------------------------------------------
    // Center section. These are the two progress bars.
    // -------------------------------------------------------------
    
    "Progress"
	{
		"ControlName"		    "ProgressBar"
		"fieldName"		        "Progress"
		"xpos"		            "c-130"
		"ypos"		            "328"
		"wide"		            "260"
		"tall"		            "15"
		"autoResize"		    "0"
		"pinCorner"		        "0"
		"visible"		        "1"
		"enabled"		        "1"
		"tabPosition"		    "0"
        "zpos"                  "3"
	}
    
	"InfoLabel"
	{
		"ControlName"           "Label"
		"fieldName"		        "InfoLabel"
		"xpos"		            "c-130"
		"ypos"		            "350"
		"wide"		            "260"
		"tall"		            "20"
		"autoResize"		    "0"
		"pinCorner"		        "0"
		"visible"		        "1"
		"enabled"		        "1"
		"tabPosition"		    "0"
		"labelText"		        "#GameUI_ParseBaseline"
		"textAlignment"		    "center"
		"dulltext"		        "0"
		"brighttext"		    "0"
        "zpos"                  "3"
		"textAlignment"			"north"
		"font"					"LoadingScreenStatus"
	}
    
    "Progress2"
    {
        "ControlName"		    "ProgressBar"
        "fieldName"		        "Progress2"
        "xpos"		            "c-130"
        "ypos"		            "372"
        "wide"		            "260"
        "tall"		            "15"
        "autoResize"		    "0"
        "pinCorner"		        "0"
        "visible"		        "0"
        "enabled"		        "1"
        "tabPosition"		    "0"
        "zpos"                  "3"
    }
    
	"SecondaryProgressLabel"
	{
		"ControlName"		    "Label"
		"fieldName"		        "SecondaryProgressLabel"
		"xpos"		            "c-130"
		"ypos"		            "394"
		"wide"		            "260"
		"tall"		            "15"
		"autoResize"		    "0"
		"pinCorner"		        "0"
		"visible"		        "0"
		"enabled"		        "1"
		"tabPosition"		    "0"
		"labelText"		        "Label"
		"textAlignment"		    "west"
		"dulltext"		        "1"
		"brighttext"		    "0"
        "zpos"                  "3"
		"font"					"LoadingScreenStatus"
	}
    
	"TimeRemainingLabel"
	{
		"ControlName"           "Label"
		"fieldName"		        "TimeRemainingLabel"
		"xpos"		            "c-130"
		"ypos"		            "416"
		"wide"		            "260"
		"tall"		            "15"
		"autoResize"		    "0"
		"pinCorner"		        "0"
		"visible"		        "0"
		"enabled"		        "1"
		"tabPosition"		    "0"
		"labelText"		        ""
		"textAlignment"		    "center"
		"dulltext"		        "1"
		"brighttext"		    "0"
        "zpos"                  "3"
		"font"					"LoadingScreenStatus"
	}
	
	"CancelButton"
	{
		"ControlName"		    "Button"
		"fieldName"		        "CancelButton"
		"xpos"		            "c-32"
		"ypos"		            "438"
		"wide"		            "65"
		"tall"		            "15"
		"autoResize"		    "0"
		"pinCorner"		        "0"
		"visible"		        "0"
		"enabled"		        "1"
		"tabPosition"		    "0"
		"labelText"		        "#GameUI_Cancel"
		"textAlignment"		    "center"
		"dulltext"		        "0"
		"brighttext"		    "0"
		"command"		        "Cancel"
		"Default"		        "0"
        "zpos"                  "3"
	}

    // -------------------------------------------------------------
    // Right hand section. Has pro tips.
    // -------------------------------------------------------------
	
    "BlackMesaFooterTipHeaderLabel"
	{
		"ControlName"           "Label"
		"fieldName"		        "BlackMesaFooterTipHeaderLabel"
		"xpos"		            "r200"
		"ypos"		            "350"
		"wide"		            "190"
		"tall"		            "15"
		"autoResize"		    "0"
		"pinCorner"		        "0"
		"visible"		        "0"
		"enabled"		        "1"
		"tabPosition"		    "0"
		"labelText"		        "#GameUI_ParseBaseline"
		"textAlignment"		    "north-west"
		"dulltext"		        "0"
		"brighttext"		    "1"
        "zpos"                  "3"
        "wrap"                  "1"
		"font"					"LoadingScreenPlayerCount"
	}
    
    "BlackMesaFooterTipDescriptionLabel"
	{
		"ControlName"           "Label"
		"fieldName"		        "BlackMesaFooterTipDescriptionLabel"
		"xpos"		            "r200"
		"ypos"		            "372"
		"wide"		            "190"
		"tall"		            "f-372"
		"autoResize"		    "0"
		"pinCorner"		        "0"
		"visible"		        "0"
		"enabled"		        "1"
		"tabPosition"		    "0"
		"labelText"		        "#GameUI_ParseBaseline"
		"textAlignment"		    "north-west"
		"dulltext"		        "0"
		"brighttext"		    "1"
        "zpos"                  "3"
        "wrap"                  "1"
		"font"					"LoadingScreenMapDescription"
	}
	
	"VACInfoLabel"
	{
		"ControlName"		"Label"
		"fieldName"		"VACInfoLabel"
		"xpos"		"c-150"
		"ypos"		"415"
		"wide"		"300"
		"tall"		"60"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"wrap"			"0"
		"tabPosition"		"0"
		"labelText"		"#VAC_ConnectingToSecureServer"
		"textAlignment"		"north"
		"dulltext"		"0"
		"brighttext"		"0"
		"zpos" "10"
	}
	
	"VACImage"
	{
		"ControlName"		"ImagePanel"
		"fieldName"		"VACImage"
		"xpos"		"c-16"
		"ypos"		"390"
		"wide"		"32"
		"tall"		"32"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"border"		""
		"scaleimage"	"1"
		"image"		"resource/icon_vac"
		"zpos" "10"
	}
}
