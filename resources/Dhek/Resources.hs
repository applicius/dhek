{-# LANGUAGE ForeignFunctionInterface #-}
--------------------------------------------------------------------------------
-- |
-- Module : Dhek.Resources
--
-- Application resources like compiled image assets
--------------------------------------------------------------------------------
module Dhek.Resources where

--------------------------------------------------------------------------------
import Foreign.Ptr

--------------------------------------------------------------------------------
import qualified Graphics.UI.Gtk as Gtk

--------------------------------------------------------------------------------
foreign import ccall "&align_vertical_top" alignVerticalTop :: Ptr Gtk.InlineImage
foreign import ccall "&applidok" applidok :: Ptr Gtk.InlineImage
foreign import ccall "&dialog_accept" dialogAccept :: Ptr Gtk.InlineImage
foreign import ccall "&distribute" distribute :: Ptr Gtk.InlineImage
foreign import ccall "&distribute_create" distributeCreate :: Ptr Gtk.InlineImage
foreign import ccall "&draw_eraser" drawEraser :: Ptr Gtk.InlineImage
foreign import ccall "&draw_rectangle" drawRectangle :: Ptr Gtk.InlineImage
foreign import ccall "&duplicate_rectangle" duplicateRectangle :: Ptr Gtk.InlineImage
foreign import ccall "&go_next" goNext :: Ptr Gtk.InlineImage
foreign import ccall "&go_previous" goPrevious :: Ptr Gtk.InlineImage
foreign import ccall "&rectangular_selection" rectangularSelection :: Ptr Gtk.InlineImage
foreign import ccall "&zoom_in" zoomIn :: Ptr Gtk.InlineImage
foreign import ccall "&zoom_out" zoomOut :: Ptr Gtk.InlineImage