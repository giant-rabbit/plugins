// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.googlemaps;

import java.util.List;

import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Polygon;
import com.google.android.gms.maps.model.PolygonOptions;

class PolygonBuilder implements PolygonOptionsSink {
  private final GoogleMapController mapController;
  private final PolygonOptions polygonOptions;

  PolygonBuilder(GoogleMapController mapController) {
    this.mapController = mapController;
    this.polygonOptions = new PolygonOptions();
  }

  String build() {
    final Polygon polygon = mapController.addPolygon(polygonOptions);
    return polygon.getId();
  }

  @Override
  public void setClickable(boolean clickable) {
    polygonOptions.clickable(clickable);
  }

  @Override
  public void setFillColor(int color) {
    polygonOptions.fillColor(color);
  }

  @Override
  public void setPoints(List<LatLng> points) {
    polygonOptions.addAll(points);
  }

  @Override
  public void setStrokeColor(int color) {
    polygonOptions.strokeColor(color);
  }
}
