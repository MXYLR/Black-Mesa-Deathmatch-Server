"resource/HudLayout.res"
{	
	CHudHealth
	{
		"fieldName"					"CHudHealth"
		"visible"					"1"
		"enabled"					"1"
		"xpos"						"16"
		"ypos"						"r36"
		"wide"						"74"
		"tall"						"20"
		"visible"					"1"
		"paintbackground"			"0"
		"font"						"HudTextLarge"
		"digits"					"3" 
		"warnIfLessThan"			"25" 
		"gapSize"					"1"
		"TextFGColor"				"OrangeDim" 
		"TextBGColor"				"OrangeDark" 
		"NormalTextFGColor"			"Orange" 
		"NormalBrightTextFGColor"	"OrangeBright" 
		"NormalTextBGColor"			"OrangeDark" 
		"NormalTextFGColor"			"Red" 
		"NormalBrightTextFGColor"	"RedBright" 
		"WarnTextBGColor"			"RedDark"
		"DotSize"					"10"
		"DotTexture"				"vgui/hud/hud_dot"
		"CrossSize"					"14"
		"CrossTexture"				"vgui/hud/hud_health_overlay"
	}

	CHudHealthHealPool
	{
		"fieldName"					"CHudHealthHealPool"
		"visible"					"1"
		"enabled"					"1"
		"xpos"						"16"
		"ypos"						"r36"
		"wide"						"74"
		"tall"						"20"
		"visible"					"1"
		"paintbackground"			"0"
		"font"						"HudTextLarge"
		"digits"					"3" 
		"warnIfLessThan"			"25" 
		"gapSize"					"1"
		"TextFGColor"				"OrangeDim" 
		"TextBGColor"				"LightBlue" 
		"NormalTextFGColor"			"Orange" 
		"NormalBrightTextFGColor"	"OrangeBright" 
		"NormalTextBGColor"			"LightBlue" 
		"NormalTextFGColor"			"Red" 
		"NormalBrightTextFGColor"	"RedBright" 
		"WarnTextBGColor"			"RedDark"
		"DotSize"					"10"
		"DotTexture"				"vgui/hud/hud_dot"
		"CrossSize"					"14"
		"CrossTexture"				"vgui/hud/hud_health_overlay"
	}

	CHudArmor
	{
		"fieldName"					"CHudArmor"
		"visible"					"1"
		"enabled"					"1"
		"xpos"						"90"
		"ypos"						"r36"
		"wide"						"74"
		"tall"						"20"
		"visible"					"1"
		"paintbackground"			"0"
		"digits"					"3" 
		"warnIfLessThan"			"25" 
		"font"						"HudTextLarge"
		"gapSize"					"1"
		"TextFGColor"				"OrangeDim" 
		"TextBGColor"				"OrangeDark" 
		"NormalTextFGColor"			"Orange" 
		"NormalBrightTextFGColor"	"OrangeBright" 
		"NormalTextBGColor"			"OrangeDark" 
		"NormalTextFGColor"			"Red" 
		"NormalBrightTextFGColor"	"RedBright" 
		"WarnTextBGColor"			"RedDark"
		"SuitSize"					"14"
		"SuitTexture"				"vgui/hud/hud_hev_overlay"
	}

	CHudCrosshair
	{
		"fieldName"				"CHudCrosshair"
		"textAlignment"			"center"
		"paintbackground"		"0"
		"brighttext"			"1"
		"centerwrap"			"1"
		"CrosshairColor"		"OrangeBright" 
	}

	CHudWeaponSelection
	{
		"fieldName"				"CHudWeaponSelection"
		"visible"				"1"
		"enabled"				"1"
		"xpos"					"16"
		"ypos"					"16"
		"wide"					"f0"
		"tall"					"f0"
		"paintbackground"		"0"
		"BoxXGap"				"2"
		"BoxYGap"				"2"
		"BoxNormalColor"		"OrangeDark" 
		"BoxBrightColor"		"OrangeBright" 
		"SlotTextColor"			"OrangeBright"
		"BoxCanSelectBgColor"	"OrangeDarker" 
		"BoxCanotSelectBgColor" "OrangeDarkest"
		"AmmoFullColor"			"GreenDark" 
		"AmmoEmptyColor"		"RedDark"
		"AmmoFullSelectColor"	"Green"
		"AmmoEmptySelectColor"	"Red"
		"slotfont"				"HudTextVerySmall"
		"BoxSize"				"10"
		"BoxSelectedHeight"		"28"
		"BoxSelectedWidth"		"75"
		"ImageGap"				"2"
		"ImageHeight"			"25"
		"ImageWidth"			"75"
		"PrimaryAmmoOffsetX"	"4"
		"PrimaryAmmoOffsetY"	"25"
		"PrimaryAmmoWidth"		"12"
		"PrimaryAmmoHeight"		"2"
		"SecondaryAmmoOffsetX"	"59"
		"SecondaryAmmoOffsetY"	"25"
		"SecondaryAmmoWidth"	"12"
		"SecondaryAmmoHeight"	"2"
	}

	CHudWeaponPrimaryAmmo
	{
		"fieldName"				"CHudWeaponPrimaryAmmo"
		"visible"				"1"
		"enabled"				"1"
		"xpos"					"r140"
		"ypos"					"r36"
		"wide"					"100"
		"tall"					"20"
		"visible"				"1"
		"paintbackground"		"0"
		"clipfont"				"HudTextLarge"
		"reservefont"			"HudTextSmall"
		"digits"				"3" 
		"DotSize"				"10"
		"DotTexture"			"vgui/hud/hud_dot"
		"AmmoIconSize"			"20"
		"warnIfLessThan"		"25" // percent
		"gapSize"				"1"
		"NormalTextFGColor"			"Orange" 
		"NormalBrightTextFGColor"	"OrangeBright" 
		"NormalTextBGColor"			"OrangeDark" 
		"NormalTextFGColor"			"Red" 
		"NormalBrightTextFGColor"	"RedBright" 
		"WarnTextBGColor"			"RedDark"
	}

	CHudSecondaryPrimaryAmmo
	{
		"fieldName"				"CHudSecondaryPrimaryAmmo"
		"visible"				"1"
		"enabled"				"1"
		"xpos"					"r104"
		"ypos"					"r36"
		"wide"					"100"
		"tall"					"20"
		"visible"				"1"
		"paintbackground"		"0"

		"clipfont"				"HudTextSmall"
		"reservefont"			"HudTextSmall"

		"digits"				"1" 

		"AmmoIconSize"			"20"

		"warnIfLessThan"		"25" // percent

		"gapSize"				"1"

		"NormalTextFGColor"			"Orange" 
		"NormalBrightTextFGColor"	"OrangeBright" 
		"NormalTextBGColor"			"OrangeDark" 
		"NormalTextFGColor"			"Red" 
		"NormalBrightTextFGColor"	"RedBright" 
		"WarnTextBGColor"			"RedDark"
	}

	CHudWeaponSecondaryAmmo
	{
		"fieldName"				"CHudWeaponSecondaryAmmo"
		"visible"				"1"
		"enabled"				"1"
		"xpos"					"16"
		"ypos"					"r36"
		"wide"					"74"
		"tall"					"20"
		"visible"				"1"
		"paintbackground"		"0"
	}

	CHudItemPickup
	{
		"fieldName"				"CHudItemPickup"
		"visible"				"1"
		"enabled"				"1"
		"xpos"					"r80"
		"ypos"					"c-150"
		"wide"					"80"
		"tall"					"320"
		"paintbackground"		"0"
		 
		"font"					"HudTextPickup"

		"BucketXGap"			"5"
		"BucketYGap"			"2"

		"WeaponImageWidth"		"75"
		"WeaponImageHeight"		"25"

		"AmmoImageWidth"		"25"
		"AmmoImageHeight"		"25"

		"ItemImageWidth"		"25"
		"ItemImageHeight"		"25"

		"NormalColor"			"OrangeDim" 
		"BrightColor"			"OrangeBright" 
	}
	
	CHudPlayerInformation
	{
		"fieldName"				"CHudPlayerInformation"
		"visible"				"0"
		"enabled"				"1"
		"xpos"					"c-320"
		"ypos"					"c+120"
		"wide"					"640"
		"tall"					"60"
		"paintbackground"		"0"
		
		"font"					"HudTextSmall"
	}
	
	CHudLongJump
	{
		"fieldName"				"CHudLongJump"
		"visible"				"1"
		"enabled"				"1"
		"xpos"					"164"
		"ypos"					"r36"
		"wide"					"64"
		"tall"					"20"
		"paintbackground"		"0"
		"padding"				"3"
	}
	
	CHudLongJumpImpactCompensation
	{
		"fieldName"				"CHudLongJumpImpactCompensation"
		"visible"				"1"
		"enabled"				"1"
		"xpos"					"c-40"
		"ypos"					"c+212"
		"wide"					"100"
		"tall"					"10"
		"paintbackground"		"0"
		"padding"				"3"
	}

	HudChat
	{
		"fieldName" "HudChat"
		"visible" "0"
		"enabled" "1"
		"xpos"	"0"
		"ypos"	"0"
		"wide"	 "4"
		"tall"	 "4"
	}

//
//	MARK - TODO REVIEW THE FOLLOWING
//
	CHudLogo
	{
		"fieldName"				"CHudLogo"
		"enabled"				"1"
		"xpos"					"0"
		"ypos"					"0"
		"wide"					"r"
		"tall"					"480"
		"visible"				"1"
		"paintbackground"		"0"
		
		"font"					"MenuTitle"
	}
	
	HudCredits
	{
		"fieldName"			"HudCredits"
		"visible"			"1"
		"enabled"			"1"
		"xpos"				"0"
		"ypos"				"0"
		"wide"				"640"
		"tall"				"480"
		"paintbackground"	"0"
	}
	
	CHudFreezePanel
	{
		"fieldName"			"CHudFreezePanel"
		"visible"			"1"
		"enabled"			"1"
		"xpos"				"r330"
		"ypos"				"r49"
		"wide"				"320"
		"tall"				"39"
		"paintbackground"	"1"
		
		"CrossSize"			"15"
		"CrossTexture"		"vgui/hud/hud_health_overlay"
		"CrossX"			"34"
		"CrossY"			"3"
		
		"HEVSize"			"15"
		"HEVTexture"		"vgui/hud/hud_hev_overlay"
		"HEVX"				"37"
		"HEVY"				"22"
		
		"WeaponX"			"52"
		"WeaponHeight"		"25"
	}

	CHudEndCredits
	{
		"fieldName"			"CHudEndCredits"
		"visible"			"1"
		"enabled"			"1"
		"xpos"				"0"
		"ypos"				"0"
		"wide"				"640"
		"tall"				"480"
		"paintbackground"	"0"

		"LogoX"				"128"
		"LogoY"				"32"
		"LogoW"				"256"
		"LogoH"				"32"

		"BgX"				"0"
		"BgY"				"0"
		"BgW"				"640"
		"BgH"				"480"

		"imageborder"		"1"
		"imagexoffset"		"128"
		"imagesize"			"96"
		"imagespacing"		"16"

		"namesxoffset"		"64"
		"defaultspacing"	"6"
		"titlespace"		"32"
		"subtitlespace"		"32"

		"TitleFont"			"CreditsTitle" 
		"SubTitleFont"		"CreditsSubTitle" 
		"NameFont"			"CreditsNames" 
		"QuoteFont"			"BootSeqTextVerySmall"

		"TitleColor"		"190 223 245 255"
		"SubTitleColor"		"255 228 181 255"
		"NameColor"			"255 255 255 255" 
		"QuoteColor"		"200 228 181 255"
	}

	HUDQuickInfo
	{
		"fieldName" "HUDQuickInfo"
		"visible" "1"
		"enabled" "1"
		"wide"	 "640"
		"tall"	 "480"
	}

	CHudBugNodes
	{
		"fieldName"				"CHudBugNodes"
		"enabled"				"1"
		"paintbackground"		"0"
		"xpos"					"0"
		"ypos"					"0"
		"wide"					"640"
		"tall"					"480"
		"visible"				"1"
	}

	CHudAir
	{
		"fieldName"				"CHudAir"
		"enabled"				"1"
		"xpos"					"10"
		"ypos"					"r130"
		"wide"					"60"
		"tall"					"60"
		"visible"				"1"
		"paintbackground"		"0"
		"textAlignment"			"west"
		"font"					"HudTextSmall"
		"ColorLowAir"			"Red"
		"ColorFullAir"			"FgColor"
	}

	CHudPrimaryAmmoIcon
	{
		"enabled"				"1"
		"scaleImage"			"1"
		"drawColor"				"FgColor"
		"xpos"					"r43"
		"ypos"					"r36"
		"xoffset_noclip"		"-40"
		"yoffset_noclip"		"0"
		"wide"					"15"
		"tall"					"15"
		"visible"				"1"
		"paintbackground"		"1"
		"shiftime"				"0.1"
	}

	CHudSecondaryAmmoIcon
	{
		"enabled"				"1"
		"scaleImage"			"1"
		"drawColor"				"FgColor"
		"xpos"					"r20"
		"ypos"					"r36"
		"xoffset_noclip"		"0"
		"yoffset_noclip"		"0"
		"wide"					"15"
		"tall"					"15"
		"visible"				"1"
		"paintbackground"		"1"
		"shiftime"				"0.1"
	}


	CHudAmmoDot
	{
		"enabled"				"1"
		"scaleImage"			"1"
		"drawColor"				"FgColor"
		"xpos"					"r128"
		"ypos"					"r40"
		"wide"					"10"
		"tall"					"10"
		"visible"				"1"
		"paintbackground"		"1"
	}

	CHudClip
	{
		"enabled"				"1"
		"font"					"LargeNumber"
		"textAlignment"			"east"
		"xpos"					"r147"
		"ypos"					"r44"
		"wide"					"74"
		"tall"					"30"
		"visible"				"1"
		"paintbackground"		"0"
		"textAlignment"			"east"
	}
			
	CHudVerticalAmmoSeparator
	{
		"enabled"				"1"
		"scaleImage"			"1"
		"drawColor"				"BrightFg"
		"xpos"					"r70"
		"ypos"					"r41"
		"wide"					"5"
		"tall"					"20"
		"visible"				"1"
		"paintbackground"		"1"
	}

	CHudPrimaryAmmo
	{
		"enabled"				"1"
		"font"					"SmallNumber"
		"xpos"					"r101"
		"ypos"					"r43"
		"wide"					"60"
		"tall"					"21"
		"visible"				"1"
		"paintbackground"		"0"
		"textAlignment"			"east"
	}
	
	CHudSecondaryAmmo
	{
		"enabled"				"1"
		"font"					"SmallNumber"
		"xpos"					"r63"
		"ypos"					"r43"
		"wide"					"42"
		"tall"					"21"
		"visible"				"1"
		"paintbackground"		"0"
		"textAlignment"			"east"
	}
	
	CHudBuildInfo
	{
		"enabled"				"1"
		"xpos"					"0"
		"ypos"					"0"
		"wide"					"r0"
		"tall"					"r0"
		"visible"				"1"
		"paintbackground"		"1"
	}

	CHudIntroCredits
	{
		"enabled"				"1"
		"paintbackground"		"0"
		"xpos"					"20"
		"ypos"					"r50"
		"wide"					"300"
		"tall"					"35"
		"visible"				"1"
		"delaystart"			"28"
		"shifttime"				"2"
		"verticalshift"			"1"
		"fadetime"				"6.0"
		"fadedelay"				"3.5"
		"fadeonlyvisible"		"1"
		"fadeonlytop"			"1"
	}
	
	CHudIntroCreditsLabel
	{
		"enabled"				"1"
		"font"					"CreditsNames"
		"textAlignment"			"west"
		"paintbackground"		"0"
		"wide"					"300"
		"tall"					"35"
		"visible"				"1"
		"brighttext"			"1"
	}
	
	CBootUpSequenceFiles
	{
		"enabled"				"1"
		"paintbackground"		"0"
		"xpos"					"32"	
		"ypos"					"r240"	
		"wide"					"300"
		"tall"					"130"
		"visible"				"1"
		"delaystart"			"1.0"
		"shifttime"				"0.25"
		"verticalshift"			"1"
		"fadetime"				"1.5"
		"fadedelay"				"0"
		"fadeonlyvisible"		"1"
		"fadeonlytop"			"0"
		"filestoshow"			"20"	//In bootup_english.txt. "PATHXX"
		"addelay"				"0.35"
	}
	
	CLongJumpSequenceFiles
	{
		"enabled"				"1"
		"paintbackground"		"0"
		"xpos"					"32"	
		"ypos"					"r240"	
		"wide"					"300"
		"tall"					"130"
		"visible"				"1"
		"delaystart"			"1.0"
		"shifttime"				"0.15"
		"verticalshift"			"1"
		"fadetime"				"1.0"
		"fadedelay"				"0"
		"fadeonlyvisible"		"1"
		"fadeonlytop"			"0"
		"filestoshow"			"20"	//In bootup_english.txt. "PATHXX"
		"addelay"				"0.35"
	}
	CHudBootUpSequencePathLine
	{
		"enabled"				"1"
		"font"					"SuitPathLineText"
		"textAlignment"			"west"
		"paintbackground"		"0"
		"wide"					"300"
		"tall"					"25"
		"visible"				"1"
		"brighttext"			"1"
	}
	
	CudLongJumpSequencePathLine
	{
		"enabled"				"1"
		"font"					"SuitPathLineText"
		"textAlignment"			"west"
		"paintbackground"		"0"
		"wide"					"300"
		"tall"					"25"
		"visible"				"1"
		"brighttext"			"1"
	}
	
	
	CBootUpSequenceActivation
	{
		"ActivationPhases"
		{
			"PHASEA"
			{
				"SubPhases"
				{
					"PHASEAA"
					{
					}
					"PHASEAB"
					{
					}
					"PHASEAC"
					{
					}
				}
				
				"starttime"	"13.0"
				"panelDuration" "4.5" //default is 5.0 if not specified.
			}
			
			"PHASEB"
			{
				"SubPhases"
				{
					"PHASEBA"
					{
						"readystring"		"ACTIVATED"
						"notreadystring"	"DEACTIVATED"
					}
					"PHASEBB"
					{
						"readystring"		"ACTIVATED"
						"notreadystring"	"DEACTIVATED"
					}
				}
				
				"starttime"	"18.0"
				"panelDuration" "4.5"
			}
			
			"PHASEC"
			{
				"SubPhases"
				{
					"PHASECA"
					{
					}
					"PHASECB"
					{
					}
					"PHASECC"
					{
					}
				}
				
				"starttime"	"23.0"
				"panelDuration" "4.5"
			}
			
			"PHASED"
			{
				"SubPhases"
				{
					"PHASEDA"
					{
						"readystring"		"ONLINE"
						"notreadystring"	"OFFLINE"
					}
					"PHASEDB"
					{
						"readystring"		"ONLINE"
						"notreadystring"	"OFFLINE"
					}
					"PHASEDC"
					{
						"readystring"		"ACTIVATED"
						"notreadystring"	"DEACTIVATED"
					}
					"PHASEDD"
					{
						"changeready" "0"
						"notreadystring"	"NOTAVAILABLE"
					}
					"PHASEDE"
					{
						"changeready" "0"
						"notreadystring"	"NOTAVAILABLE"
					}
				}
				"starttime"	"28.0"
				"panelDuration" "4.5"
			}
			
			"PHASEE"
			{
				"SubPhases"
				{
					"PHASEEA"
					{
						"readystring"		"ACTIVATED"
						"notreadystring"	"DEACTIVATED"
					}
				}
				"starttime"	"33.0"
				"panelDuration" "2.5" 
			}
			
			"PHASEF"
			{
				"SubPhases"
				{
					"PHASEFA"
					{
						"readystring"		"ONLINE"
						"notreadystring"	"OFFLINE"
					}
					
					"PHASEFB"
					{
						"readystring"		"ONLINE"
						"notreadystring"	"OFFLINE"
					}
					
					"PHASEFC"
					{
						"readystring"		"ENABLED"
						"notreadystring"	"DISABLED"
					}
					
					"PHASEFD"
					{
						"readystring"		"ONLINE"
						"notreadystring"	"OFFLINE"
					}
					
					"PHASEFE"
					{
					}
				}
				"starttime"	"36.0"
			}
		}
		
		"enabled"				"1"
		"headerfont"			"SuitBootUpTitle"
		"itemfont"				"SuitBootUpTextSmall"
		"linespacing"			"30"
		"sectiongap"			"50"
		"paintbackground"		"0"
		"xpos"					"32"	
		"ypos"					"r300"	
		"SuitXGapSize"			"1"
		"wide"					"300"
		"tall"					"200"
		"visible"				"1"
		"brighttext"			"1"
	}
	
	
	CLongJumpSequenceActivation
	{
		"ActivationPhases"
		{			
			"PHASEA"
			{
				"starttime"	"1.0"
				"panelDuration" "2.2" //default is 5.0 if not specified.
			}
			"PHASEB"
			{
				"SubPhases"
				{
					"PHASEBA"
					{
						"readystring"		"ACTIVATED"
						"notreadystring"	"STANDBY2"
					}
					"PHASEBB"
					{
						"readystring"		"ONLINE"
						"notreadystring"	"OFFLINE"
					}
					"PHASEBC"
					{
						"readystring"		"ONLINE"
						"notreadystring"	"OFFLINE"
					}
					"PHASEBD"
					{
						"readystring"		"ONLINE"
						"notreadystring"	"OFFLINE"
					}
					"PHASEBE"
					{
						"readystring"		"ONLINE"
						"notreadystring"	"OFFLINE"
					}
				}
				"starttime"	"1.6"
				"panelDuration" "4.4"
			}
		}
		
		"enabled"				"1"
		"headerfont"			"LJBootUpChecklistHeader"
		"itemfont"				"LJBootUpChecklistItems"
		"linespacing"			"22"
		"sectiongap"			"50"
		"paintbackground"		"0"
		"xpos"					"32"	
		"ypos"					"r300"	
		"SuitXGapSize"			"1"
		"wide"					"300"
		"tall"					"200"
		"visible"				"1"
		"brighttext"			"1"
	}
	
	
	
	CBootUpSequenceTitle
	{
		"enabled"				"1"
		"font"					"SuitBootUpTitle"
		"textAlignment"			"center"
		"paintbackground"		"0"
		"wide"					"500"
		"tall"					"25"
		"visible"				"1"
		"brighttext"			"1"
	}
	
	
	CLongJumpSequenceTitle
	{
		"enabled"				"1"
		"font"					"LJBootUpCenterTitles"
		"textAlignment"			"center"
		"paintbackground"		"0"
		"wide"					"250"
		"tall"					"15"
		"visible"				"1"
		"brighttext"			"1"
	}
	
	CBootUpSequenceVersion
	{
		"enabled"				"1"
		"font"					"HudTextVerySmall"
		"textAlignment"			"center"
		"paintbackground"		"0"
		"wide"					"300"
		"tall"					"25"
		"visible"				"1"
		"brighttext"			"1"
	}
	CLongJumpSequenceVersion
	{
		"enabled"				"1"
		"font"					"HudTextVerySmall"
		"textAlignment"			"center"
		"paintbackground"		"0"
		"wide"					"300"
		"tall"					"25"
		"visible"				"1"
		"brighttext"			"1"
	}
	
	CBootUpSequenceStandby
	{
		"enabled"				"1"
		"font"					"SuitBootUpTextSmall"
		"textAlignment"			"center"
		"xpos"					"r83"
		"ypos"					"116"
		"paintbackground"		"0"
		"wide"					"250"
		"tall"					"15"
		"visible"				"1"
		"brighttext"			"1"
	}
	
	CLongJumpSequenceStandby
	{
		"enabled"				"1"
		"font"					"LJBootUpCenterTitles"
		"textAlignment"			"center"
		"paintbackground"		"0"
		"wide"					"300"
		"tall"					"25"
		"visible"				"1"
		"brighttext"			"1"
		"TextFGColor"				"Orange" 
		"//TextBGColor"				"OrangeDark" 
		// "NormalTextFGColor"			"Orange" 
		// "NormalBrightTextFGColor"	"OrangeBright" 
		// "NormalTextBGColor"			"OrangeDark" 
		// "NormalTextFGColor"			"Red" 
		// "NormalBrightTextFGColor"	"RedBright"
	}
	
	CLongJumpSequenceSysCheck
	{
		"enabled"				"1"
		"font"					"LJBootUpCenterTitles"
		"textAlignment"			"center"
		"paintbackground"		"0"
		"wide"					"300"
		"tall"					"25"
		"visible"				"1"
		"brighttext"			"1"
	}
	
	CLongJumpSequenceSysCheck2
	{
		"enabled"				"1"
		"font"					"LJBootUpCenterTitles"
		"textAlignment"			"center"
		"paintbackground"		"0"
		"wide"					"500"
		"tall"					"25"
		"visible"				"1"
		"brighttext"			"1"
	}

	CHudWeaponPickup
	{
		"enabled"				"1"
		"paintbackground"		"0"
		"xpos"					"r83"
		"ypos"					"116"
		"wide"					"75"
		"tall"					"244"
		"visible"				"1"
		"shifttime"				"0"
		"verticalshift"			"1"
		"fadetime"				"0.5"
		"fadedelay"				"3.0"
		"fadeonlyvisible"		"1"
		"fadeonlytop"			"0"
	}
	
	CHudWeaponPickupLabel
	{
		"enabled"				"1"
		"font"					"PickupLabel"
		"textAlignment"			"east"
		"paintbackground"		"0"
		"wide"					"150"
		"tall"					"48"
		"visible"				"1"
		"brighttext"			"1"
	}

	CHudDamageDirection
	{
		"enabled"				"1"
		"paintbackground"		"0"
		"xpos"					"0"
		"ypos"					"0"
		"wide"					"640"
		"tall"					"480"
		"visible"				"1"
	}
		
	CHudDamageType
	{
		"enabled"				"1"
		"paintbackground"		"0"
		"xpos"					"12"
		"ypos"					"r72"
		"wide"					"200"
		"tall"					"20"
		"visible"				"1"
		"shifttime"				"0.25"
		"verticalshift"			"0"
		"fadetime"				"1.5"
		"fadedelay"				"1.5"
		"fadeonlyvisible"		"0"
		"fadeonlytop"			"0"
	}
	
	CHudHealPool
	{
		"enabled"				"1"
		"paintbackground"		"0"
		"xpos"					"0"
		"ypos"					"0"
		"wide"					"640"
		"tall"					"480"
		"visible"				"1"
	}
	
	HudGeiger
	{
		"fieldName" "HudGeiger"
		"visible" "1"
		"enabled" "1"
		"wide"	 "640"
		"tall"	 "480"
	}
	
	// Chapter titles are using this HUD. 
	// the chapter Forget About Freeman is the longest name in english and needs at least a wide of 670 in 21:9
	// Let s use 700 then.
	HudMessage
	{
		"fieldName" "HudMessage"
		"visible" "1"
		"enabled" "1"
		"wide"	 "700"
		"tall"	 "480"
	}
	
	HudHintDisplay
	{
		"fieldName"				"HudHintDisplay"
		"visible"				"0"
		"enabled"				"1"
		"xpos"					"r120"	
		"ypos"					"r340"	
		"wide"					"100"
		"tall"					"200"
		"text_xpos"				"8"
		"text_ypos"				"8"
		"text_xgap"				"8"
		"text_ygap"				"8"
		"TextColor"				"255 170 0 220"
		"PaintBackgroundType"	"2"
	}

	HudHintKeyDisplay
	{
		"fieldName"				"HudHintKeyDisplay"
		"visible"				"0"
		"enabled" 				"1"
		"xpos"					"r120"	
		"ypos"					"r340"	
		"wide"					"100"
		"tall"					"200"
		"text_xpos"				"8"
		"text_ypos"				"8"
		"text_xgap"				"8"
		"text_ygap"				"8"
		"TextColor"				"255 170 0 220"
		"PaintBackgroundType"	"2"
	}
	
	HudAnimationInfo
	{
		"fieldName" "HudAnimationInfo"
		"visible" "1"
		"enabled" "1"
		"wide"	 "640"
		"tall"	 "480"
	}
	
	HudPredictionDump
	{
		"fieldName" "HudPredictionDump"
		"visible" "1"
		"enabled" "1"
		"wide"	 "640"
		"tall"	 "480"
	}
	
	
	AchievementNotificationPanel	
	{
		"fieldName"				"AchievementNotificationPanel"
		"visible"				"1"
		"enabled"				"1"
		"xpos"					"0"
		"ypos"					"10"
		"wide"					"f60"	
		"tall"					"100"
		"paintbackground"		"0"
	}
		
	HudCommentary
	{
		"fieldName" "HudCommentary"
		"xpos"	"c-190"
		"ypos"	"350"
		"wide"	"380"
		"tall"  "40"
		"visible" "1"
		"enabled" "1"
		
		"PaintBackgroundType"	"2"
		
		"bar_xpos"		"50"
		"bar_ypos"		"20"
		"bar_height"	"8"
		"bar_width"		"320"
		"speaker_xpos"	"50"
		"speaker_ypos"	"8"
		"count_xpos_from_right"	"10"	// Counts from the right side
		"count_ypos"	"8"
		
		"icon_texture"	"vgui/hud/icon_commentary"
		"icon_xpos"		"0"
		"icon_ypos"		"0"		
		"icon_width"	"40"
		"icon_height"	"40"
	}
		
	HudMenu
	{
		"fieldName" "HudMenu"
		"visible" "1"
		"enabled" "1"
		"wide"	 "640"
		"tall"	 "480"
		"zpos" "1"

		"TextFont"				"Default"
		"ItemFont"				"Default"
		"ItemFontPulsing"		"Default"
	}
	
	HudCloseCaption
	{
		"fieldName" "HudCloseCaption"
		"visible"	"0"
		"enabled"	"1"
		"xpos"		"c-250"
		"ypos"		"276"	
		"wide"		"500"
		"tall"		"136"	

		"BgAlpha"	"128"

		"GrowTime"		"0.25"
		"ItemHiddenTime"	"0.2"  // Nearly same as grow time so that the item doesn't start to show until growth is finished
		"ItemFadeInTime"	"0.15"	// Once ItemHiddenTime is finished, takes this much longer to fade in
		"ItemFadeOutTime"	"0.3"
		"topoffset"		"0"		
	}
	
	HUDAutoAim
	{
		"fieldName" "HUDAutoAim"
		"visible" "1"
		"enabled" "1"
		"wide"	 "640"	
		"tall"	 "480"	
	}
	
	HudVehicle
	{
		"fieldName" "HudVehicle"
		"visible" "0"
		"enabled" "0"
		"wide"	 "640"
		"tall"	 "480"
	}
	
	HudTrain
	{
		"fieldName" "HudTrain"
		"visible" "0"
		"enabled" "0"
		"wide"	 "640"
		"tall"	 "480"
	}
	
	CHudMultiplayer
	{
		"fieldName"			"CHudMultiplayer"
		"visible"			"0"
		"enabled"			"0"
		"wide"				"640"
		"tall"				"480"
		"enabled" 			"1"
		"visible"			"1"
		"paintbackground" 	"0"		
		
		"HeaderFont"		"HudMultiplayerHeader"
		"BodyFont"			"HudMultiplayerBody"	
		"TextYOffset"		"1"
	}
	
	CHudDeathNotice
	{
		"enabled" "1"
		"paintbackground" "0"
		"xpos" "r312"
		"ypos" "12"
		"wide" "300"
		"tall" "200"
		"visible" "1"
		"shifttime" "0.25"
		"bestfit" "0"
		"reverse" "0"
		"verticalshift" "1"
		"fadetime" "0.5"
		"fadedelay" "6"
		"fadeonlyvisible" "0"
		"fadeonlytop" "0"
	}

	CHudDeathNoticeLabel
	{
		"enabled" "1"
		"font" "HudTextSmall"
		"textAlignment"	"east"
		"paintbackground" "0"
		"wide" "300"
		"tall" "20"
		"visible" "1"
		
		"DefaultTextColor" "OrangeBright"	// Color when not in teamplay.
		"BackgroundColor" "TransparentLightBlack"
		
		"TextColorSelf" "255 255 255 128"
		"BackgroundSelfAlpha" "15"		// Background color comes from team color.
		
		"Padding" "7"
	}
	
	CHudDominationNoticeLabel
	{
		"enabled" "1"
		"font" "HudTextSmall"
		"textAlignment"	"east"
		"paintbackground" "0"
		"wide" "300"
		"tall" "20"
		"visible" "1"
		
		"DefaultTextColor" "OrangeBright"	// Color when not in teamplay.
		"BackgroundColor" "TransparentBlack"
		
		"TextColorSelf" "255 255 255 128"
		"BackgroundSelfAlpha" "30"		// Background color comes from team color.
		
		"Padding" "7"
	}
	
	HudHistoryResource
	{
		"fieldName" "HudHistoryResource"
		"visible" "0"
		"enabled" "0"
		"wide"	 "640"
		"tall"	 "480"
	}
    
    HudSubtitles
	{
		"fieldName"				"HudSubtitles"
		"visible"				"0"
		"enabled"				"0"
	}
    
   	HudSaveStatus
	{
		"fieldName"				"HudSaveStatus"
		"visible"				"0"
		"enabled"				"0"
	}

	HudVoiceSelfStatus
	{
		"fieldName" "HudVoiceSelfStatus"
		"paintbackground"			"0"
		"visible" "1"
		"enabled" "1"
		"xpos" "r43"
		"ypos" "355"
		"wide" "24"
		"tall" "24"
		"TextFGColor"				"OrangeDim" 
		"TextBGColor"				"OrangeDark" 
		"NormalTextFGColor"			"Orange" 
		"NormalBrightTextFGColor"	"OrangeBright" 
		"NormalTextBGColor"			"OrangeDark" 
		"NormalTextFGColor"			"Red" 
		"NormalBrightTextFGColor"	"RedBright"
	}

	HudVoiceStatus
	{
		"paintbackground"			"0"
		"fieldName" "HudVoiceStatus"
		"visible" "1"
		"enabled" "1"
		"xpos" "16"
		"ypos" "0"
		"wide" "240"
		"tall" "400"

		// Voice indicator for each player layout settings
		// suppose that items have 8px padding so add it to each x pos

		"item_tall" "32"
		"item_wide" "240"
		"item_spacing" "8"

		// Speaker icon
		"show_voice_icon" "1"
		"voice_icon_ypos" "0"
		"voice_icon_xpos" "0"
		"voice_icon_tall" "32"
		"voice_icon_wide" "32"

		// Avatar icon
		"show_avatar" "1"
		"show_friend" "1"
		"avatar_tall" "32"
		"avatar_wide" "32"

		// Dead indicator icon
		"show_dead_icon" "0"
		"dead_ypos" "0"
		"dead_xpos" "0"
		"dead_tall" "32"
		"dead_wide" "32"

		// Player name pos
		"text_xpos" "80"

		"fade_in_time" "0.0"
		"fade_out_time" "0.0"

		"TextFGColor"				"OrangeDim" 
		"TextBGColor"				"OrangeDark" 
		"NormalTextFGColor"			"Orange" 
		"NormalBrightTextFGColor"	"OrangeBright" 
		"NormalTextBGColor"			"OrangeDark" 
		"NormalTextFGColor"			"Red" 
		"NormalBrightTextFGColor"	"RedBright"
	}
}