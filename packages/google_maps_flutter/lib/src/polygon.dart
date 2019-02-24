// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of google_maps_flutter;

/// An polygon placed at a particular geographical location on the map's
/// surface.
/// A polygon is drawn oriented against the device's screen rather than the
/// map's surface; that is, it will not necessarily change orientation due to
/// map rotations, tilting, or zooming.
///
/// Polygons are owned by a single [GoogleMapController] which fires events
/// as polygons are added, updated, tapped, and removed.
class Polygon {
  @visibleForTesting
  Polygon(this._id, this._options);

  /// A unique identifier for this polygon.
  ///
  /// The identirifer is an arbitrary unique string.
  final String _id;
  String get id => _id;

  PolygonOptions _options;

  /// The polygon configuration options most recently applied programmatically
  /// via the map controller.
  ///
  /// The returned value does not reflect any changes made to the polygon through
  /// touch events. Add listeners to the owning map controller to track those.
  PolygonOptions get options => _options;
}

/// Configuration options for [Polygon] instances.
///
/// When used to change configuration, null values will be interpreted as
/// "do not change this configuration option".
class PolygonOptions {
  /// Creates a set of polygon configuration options.
  ///
  /// By default, every non-specified field is null, meaning no desire to change
  /// polygon defaults or current configuration.
  const PolygonOptions({
    this.clickable,
    this.fillColor,
    this.points,
    this.strokeColor,
  });

  final bool clickable;
  final Color fillColor;
  final List<LatLng> points;
  final Color strokeColor;

  static const PolygonOptions defaultOptions = PolygonOptions(
    fillColor: Color(0xFF000000),
    clickable: false,
    strokeColor: Color(0xFF000000),
  );

  PolygonOptions copyWith(PolygonOptions changes) {
    if (changes == null) {
      return this;
    }
    return PolygonOptions(
      clickable: changes.clickable ?? clickable,
      fillColor: changes.fillColor ?? fillColor,
      points: changes.points ?? points,
    );
  }

  dynamic _toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};

    void addIfPresent(String fieldName, dynamic value) {
      if (value != null) {
        json[fieldName] = value;
      }
    }

    addIfPresent('clickable', clickable);
    addIfPresent('fillColor', fillColor.hashCode);
    json['points'] = points.map((point) => point._toJson()).toList();
    addIfPresent('strokeColor', strokeColor.hashCode);

    return json;
  }
}
