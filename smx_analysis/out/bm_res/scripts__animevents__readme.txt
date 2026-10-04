// -------------------------------------------------------------------
//                          BLACK MESA
//                  COPYRIGHT CROWBAR COLLECTIVE
//                             2014    
// -------------------------------------------------------------------

// -------------------------------------------------------------------
// WHAT IS THIS?
// -------------------------------------------------------------------
Black Mesa allows you to customize certain parameters of weapon
ejections. This file details out what those parameters are and what
they represent. It will also document how to implement these changes
to your models.

// -------------------------------------------------------------------
// OVERALL INFORMATION
// -------------------------------------------------------------------

STEP ONE: THE QC COMMAND
    The driver of this system is the AE_CLIENT_EJECT_CUSTOM QC command.
    This command fires off an animation event in the client/server code
    which triggers the appropriate effects. The syntax of this command
    is the following:
        { event AE_CLIENT_EJECT_CUSTOM <frame> "<effect-set-name>"  }
    So a true to life example is:
        { event AE_CLIENT_EJECT_CUSTOM 30 "shotgun-primary-attack"   }

STEP TWO: THE ANIMATION SET FILE
    Every weapon that wishes to use this system must have a <weapon-entity-name>.txt
    file in this folder. For example, the shotgun has a weapon_shotgun.txt file in
    this folder.
      
    This file contains groupings in KeyValues format.
  
    // Primary attack settings.
    "shotgun-primary-attack"
    {
        // Generic variables.
        "casing_count"          "1"
        "forward_speed_min"     "4"
        "forward_speed_max"     "8"
        "right_speed_min"       "-20"
        "right_speed_max"       "-30"
        "up_speed_min"          "420"
        "up_speed_max"          "460"
        "lifetime"              "1"
        "skin"                  "0"
        "gravity"               "0.4"
        
        // FPS specific variables.
        "fps_eject_model"       "models/weapons/shotgun_shell.mdl"
    }
    
STEP THREE: COMPILE AND RUN!
