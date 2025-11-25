//
//  WidgetProperty.swift
//  PlynxConnector
//
//  Widget properties that can be changed at runtime.
//

import Foundation

/// Properties that can be set on widgets.
public enum WidgetProperty: String, Codable, Sendable {
    case label = "label"
    case color = "color"
    case onBackColor = "onBackColor"
    case offBackColor = "offBackColor"
    case onColor = "onColor"
    case offColor = "offColor"
    case onLabel = "onLabel"
    case offLabel = "offLabel"
    case labels = "labels"
    case min = "min"
    case max = "max"
    case isOnPlay = "isOnPlay"
    case url = "url"
    case urls = "urls"
    case step = "step"
    case valueFormatting = "valueFormatting"
    case suffix = "suffix"
    case maximumFractionDigits = "maximumFractionDigits"
    case opacity = "opacity"
    case scale = "scale"
    case rotation = "rotation"
}
