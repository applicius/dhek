--------------------------------------------------------------------------------
-- |
-- Module : Dhek.Signal
--
--
--------------------------------------------------------------------------------
module Dhek.Signal where

--------------------------------------------------------------------------------
import Control.Lens
import Control.Monad (when)
import Data.Foldable (for_, traverse_)

--------------------------------------------------------------------------------
import           Control.Monad.Trans (liftIO)
import qualified Graphics.UI.Gtk as Gtk

--------------------------------------------------------------------------------
import Dhek.Action (onNext, onPrev, onMinus, onPlus, onRem)
import Dhek.Draw
import Dhek.Drawing
import Dhek.GUI
import Dhek.File (onJsonImport, onJsonSave)
import Dhek.Free
import Dhek.Instr
import Dhek.Move (onMove, onPress, onRelease)
import Dhek.Property (onProp)
import Dhek.Engine
import Dhek.Selection (onSel)
import Dhek.Types

--------------------------------------------------------------------------------
connectSignals :: GUI -> Interpreter -> IO ()
connectSignals g i = do
    Gtk.on (guiPdfOpenMenuItem g) Gtk.menuItemActivate $ do
        resp <- Gtk.dialogRun $ guiPdfDialog g
        Gtk.widgetHide $ guiPdfDialog g
        case resp of
            Gtk.ResponseOk -> do
                uriOpt  <- Gtk.fileChooserGetURI $ guiPdfDialog g
                traverse_ (loadPdf i) uriOpt
            _ -> return ()

    Gtk.on (guiJsonOpenMenuItem g) Gtk.menuItemActivate $
        runProgram i onJsonImport

    Gtk.on (guiJsonSaveMenuItem g) Gtk.menuItemActivate $
        runProgram i onJsonSave

    Gtk.on (guiOverlapMenuItem g) Gtk.menuItemActivate $ runProgram i $
        compile $ do
            b <- isActive Overlap
            active Overlap (not b)

    -- Previous Button ---
    Gtk.on (guiPrevButton g) Gtk.buttonActivated $ runProgram i onPrev

    --- Next Button ---
    Gtk.on (guiNextButton g) Gtk.buttonActivated $ runProgram i onNext

    --- Minus Button ---
    Gtk.on (guiZoomOutButton g) Gtk.buttonActivated $ runProgram i onMinus

    --- Plus Button ---
    Gtk.on (guiZoomInButton g) Gtk.buttonActivated $ runProgram i onPlus
    Gtk.on (guiRemoveButton g) Gtk.buttonActivated $ runProgram i onRem
    Gtk.on (guiApplyButton g) Gtk.buttonActivated $ runProgram i onProp

    --- Selection ---
    Gtk.on (guiRectTreeSelection g) Gtk.treeSelectionSelectionChanged $ do
        runProgram i onSel

    Gtk.on (guiDrawingArea g) Gtk.exposeEvent $ Gtk.tryEvent $ liftIO $ do
        s     <- engineCurrentState i
        page  <- engineCurrentPage i
        ratio <- engineRatio i
        let ds     = s ^. engineDrawState
            params = DrawParams{ dpRatio = ratio
                               , dpSelected  = ds ^. drawSelected
                               , dpSelection = ds ^. drawSelection
                               , dpOvered    = Nothing
                               , dpRects     = getRects s
                               , dpEvent     = ds ^. drawEvent
                               , dpPage      = page
                               , dpGuides    = s ^. engineBoards.boardsGuides
                               , dpCurGuide  = s ^. engineBoards.boardsCurGuide
                               , dpArea      = engineDrawingArea i
                               }

        cairoDraw params
        hsize  <- Gtk.adjustmentGetPageSize $ guiHRulerAdjustment g
        vsize  <- Gtk.adjustmentGetPageSize $ guiVRulerAdjustment g
        hlower <- Gtk.adjustmentGetLower $ guiHRulerAdjustment g
        hupper <- Gtk.adjustmentGetUpper $ guiHRulerAdjustment g
        hincr  <- Gtk.adjustmentGetPageIncrement $ guiHRulerAdjustment g
        sincr  <- Gtk.adjustmentGetStepIncrement $ guiHRulerAdjustment g
        vincr  <- Gtk.adjustmentGetPageIncrement $ guiVRulerAdjustment g
        hvalue <- Gtk.adjustmentGetValue $ guiHRulerAdjustment g
        vvalue <- Gtk.adjustmentGetValue $ guiVRulerAdjustment g

        let w  = (hsize/ratio) + hl
            h  = (vsize/ratio) + vl
            hl = hvalue / ratio
            vl = vvalue / ratio

        Gtk.set (guiHRuler g) [ Gtk.rulerLower   Gtk.:= hl
                              , Gtk.rulerUpper   Gtk.:= w
                              , Gtk.rulerMaxSize Gtk.:= w
                              ]

        Gtk.set (guiVRuler g) [ Gtk.rulerLower   Gtk.:= vl
                              , Gtk.rulerUpper   Gtk.:= h
                              , Gtk.rulerMaxSize Gtk.:= h
                              ]

    Gtk.on (guiDrawingArea g) Gtk.motionNotifyEvent $ Gtk.tryEvent $ do
        pos@(x,y) <- Gtk.eventCoordinates
        liftIO $ do
            r <- engineRatio i

            drawInterpret i pos onMove
            Gtk.set (guiHRuler g) [Gtk.rulerPosition Gtk.:= x/r]
            Gtk.set (guiVRuler g) [Gtk.rulerPosition Gtk.:= y/r]

    Gtk.on (guiDrawingArea g) Gtk.buttonPressEvent $ Gtk.tryEvent $ do
       pos <- Gtk.eventCoordinates
       b   <- Gtk.eventButton
       when (b == Gtk.LeftButton) $
           liftIO $ drawInterpret i pos onPress

    Gtk.on (guiDrawingArea g) Gtk.buttonReleaseEvent $ Gtk.tryEvent $ do
        pos <- Gtk.eventCoordinates
        liftIO $ drawInterpret i pos onRelease

    Gtk.on (guiDrawingArea g) Gtk.scrollEvent $ Gtk.tryEvent $ do
        dir <- Gtk.eventScrollDirection
        liftIO $ do
            pageSize <- Gtk.adjustmentGetPageSize $ guiVRulerAdjustment g
            lower    <- Gtk.adjustmentGetLower $ guiVRulerAdjustment g
            upper    <- Gtk.adjustmentGetUpper $ guiVRulerAdjustment g
            step     <- Gtk.adjustmentGetStepIncrement $ guiVRulerAdjustment g
            oldValue <- Gtk.adjustmentGetValue $ guiVRulerAdjustment g
            let delta' = step * 2
                delta  = case dir of
                    Gtk.ScrollUp -> negate delta'
                    _            -> delta'
                newValue = min (upper - pageSize) (max 0 (oldValue + delta))
            Gtk.adjustmentSetValue (guiVRulerAdjustment g) newValue

    Gtk.on (guiTypeCombo g) Gtk.changed $ do
        runProgram i $ compile $ do
            opt <- getComboText PropCombo
            for_ opt $ \c ->
                if c == "radio"
                then setValuePropVisible True
                else setValuePropVisible False

    Gtk.on (guiVRuler g) Gtk.buttonPressEvent $ Gtk.tryEvent $ liftIO $
        runProgram i $ compile $ newGuide GuideVertical

    Gtk.on (guiVRuler g) Gtk.motionNotifyEvent $ Gtk.tryEvent $ do
        (x',y') <- Gtk.eventCoordinates
        liftIO $ do
            ratio <- engineRatio i
            v     <- Gtk.adjustmentGetValue (guiHRulerAdjustment g)
            let (x,y) = ((x'-25+v)/ratio, y'/ratio)

            Gtk.set (guiHRuler g) [Gtk.rulerPosition Gtk.:= x]
            Gtk.set (guiVRuler g) [Gtk.rulerPosition Gtk.:= y]

            runProgram i $ compile $ do
                updateGuide
                draw

    Gtk.on (guiVRuler g) Gtk.buttonReleaseEvent $ Gtk.tryEvent $ liftIO $
        runProgram i $ compile $ do
            addGuide
            draw

    Gtk.on (guiHRuler g) Gtk.buttonPressEvent $ Gtk.tryEvent $ liftIO $
        runProgram i $ compile $ newGuide GuideHorizontal

    Gtk.on (guiHRuler g)  Gtk.motionNotifyEvent $ Gtk.tryEvent $ do
        (x',y') <- Gtk.eventCoordinates
        liftIO $ do
            ratio <- engineRatio i
            v     <- Gtk.adjustmentGetValue (guiVRulerAdjustment g)
            let (x,y) = (x'/ratio, (y'+v-25)/ratio)

            Gtk.set (guiHRuler g) [Gtk.rulerPosition Gtk.:= x]
            Gtk.set (guiVRuler g) [Gtk.rulerPosition Gtk.:= y]

            runProgram i $ compile $ do
                updateGuide
                draw

    Gtk.on (guiHRuler g) Gtk.buttonReleaseEvent $ Gtk.tryEvent $ liftIO $
        liftIO $ runProgram i $ compile $ do
            addGuide
            draw

    Gtk.on (guiDrawToggle g) Gtk.toggled $ liftIO $
        runProgram i $ compile $ do
            b <- isToggleActive DrawToggle
            setToggleActive MultiSelToggle (not b)

    Gtk.on (guiMultiSelToggle g) Gtk.toggled $ liftIO $
        runProgram i $ compile $ do
            b <- isToggleActive MultiSelToggle
            setToggleActive DrawToggle (not b)

    return ()