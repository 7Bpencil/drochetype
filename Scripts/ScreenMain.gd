class_name ScreenMain extends Node


signal start_typing


func after_init():
    start_typing.emit()
