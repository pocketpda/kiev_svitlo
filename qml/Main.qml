/*
 * Copyright (C) 2026  kievsvitlo
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * kievsvitlo is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Lomiri.Components.Themes.Ambiance 1.3

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'kievsvitlo.kievsvitlo'
    automaticOrientation: true

    width: units.gu(45)
    height: units.gu(75)

    Page {
        id: page
        anchors.fill: parent

        header: PageHeader {
            id: header
            title: i18n.tr('KievSvitlo')
            leadingActionBar.actions: [
                Action {
                    iconSource: "assets/logo.svg"
                    text: i18n.tr("KievSvitlo")
                }
            ]
            trailingActionBar.actions: [
                Action {
                    iconName: "info"
                    text: i18n.tr("Інфо")
                    onTriggered: PopupUtils.open(infoDialogComponent)
                }
            ]
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0384; color: "#ffe261" }
                GradientStop { position: 0.5028; color: "#ffd100" }
                GradientStop { position: 0.939; color: "#f6a717" }
            }
            z: -1
        }

        property int regionId: 25
        property string regionValue: "Київ"
        property int streetId: 0
        property int houseId: 0
        property string streetValue: ""
        property string houseValue: ""
        property string groupKey: ""
        property string selectedDay: "today"
        property var outageHalves: []
        property int currentHour: (new Date()).getHours()
        property int currentMinute: (new Date()).getMinutes()
        property int powerNowPercent: -1
        property var plannedOutagesPayload: null
        property bool suppressStreetSearch: false
        property bool suppressHouseSearch: false
        property bool notificationsEnabled: true
        property string appVersion: (Qt.application.version && Qt.application.version.length > 0)
                                    ? Qt.application.version
                                    : "1.0.1"
        property string lastUpdateDate: "20.03.2026"

        Component {
            id: infoDialogComponent
            PopupBase {
                id: infoDialog
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: 0.6
                }
                Rectangle {
                    id: infoPanel
                    width: Math.min(parent.width - units.gu(4), units.gu(44))
                    height: infoContent.implicitHeight + units.gu(2)
                    radius: units.gu(0.6)
                    color: theme.palette.normal.background
                    border.color: theme.palette.normal.base
                    anchors.centerIn: parent

                    ColumnLayout {
                        id: infoContent
                        anchors.fill: parent
                        anchors.margins: units.gu(1)
                        spacing: units.gu(1)

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.bold: true
                            text: i18n.tr("Інформація")
                            color: theme.palette.normal.baseText
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: i18n.tr("Дані беруться з сайту")
                            color: theme.palette.normal.baseText
                        }

                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            textFormat: Text.RichText
                            text: "<a href=\"https://yasno.ua\">https://yasno.ua</a>"
                            color: theme.palette.normal.baseText
                            linkColor: theme.palette.normal.focus
                            onLinkActivated: Qt.openUrlExternally(link)
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: i18n.tr("Автор ПО: RosT")
                            color: theme.palette.normal.baseText
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: i18n.tr("Email: ") + "rostislav.tymkiv@gmail.com"
                            color: theme.palette.normal.baseText
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: i18n.tr("Дата оновлення: ") + lastUpdateDate
                            color: theme.palette.normal.baseText
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: i18n.tr("Поточна версія: ") + appVersion
                            color: theme.palette.normal.baseText
                        }

                        Button {
                            text: i18n.tr("OK")
                            onClicked: PopupUtils.close(infoDialog)
                        }
                    }
                }
            }
        }

        Settings {
            id: settings
            property int regionId: 0
            property string regionValue: ""
            property int streetId: 0
            property string streetValue: ""
            property int houseId: 0
            property string houseValue: ""
            property bool notificationsEnabled: true
        }

        ListModel { id: streetModel }
        ListModel { id: houseModel }
        property var alarmModel: null
        property var outageAlarm: null

        function httpGet(url, onDone) {
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    onDone(xhr.status, xhr.responseText)
                }
            }
            xhr.open("GET", url)
            xhr.send()
        }

        function persistSelection() {
            settings.regionId = regionId
            settings.regionValue = regionValue
            settings.streetId = streetId
            settings.streetValue = streetValue
            settings.houseId = houseId
            settings.houseValue = houseValue
        }

        function clearSchedule() {
            var arr = []
            for (var i = 0; i < 48; i++) {
                arr.push(false)
            }
            outageHalves = arr
        }

        function normalizeText(value) {
            return value.toLowerCase().trim()
        }

        function resolveStreetId(query, onDone) {
            if (query.length < 1) {
                onDone(0, "")
                return
            }
            var url = "https://app.yasno.ua/api/blackout-service/public/shutdowns/addresses/v2/streets" +
                      "?regionId=" + regionId + "&query=" + encodeURIComponent(query) + "&dsoId=902"
            httpGet(url, function(status, body) {
                if (status !== 200) {
                    onDone(0, "")
                    return
                }
                var data = JSON.parse(body)
                var target = normalizeText(query)
                var match = null
                for (var i = 0; i < data.length; i++) {
                    if (normalizeText(data[i].value) === target) {
                        match = data[i]
                        break
                    }
                }
                if (!match && data.length > 0) {
                    match = data[0]
                }
                onDone(match ? match.id : 0, match ? match.value : "")
            })
        }

        function resolveHouseId(streetIdValue, query, onDone) {
            if (query.length < 1 || streetIdValue === 0) {
                onDone(0, "")
                return
            }
            var url = "https://app.yasno.ua/api/blackout-service/public/shutdowns/addresses/v2/houses" +
                      "?regionId=" + regionId + "&streetId=" + streetIdValue +
                      "&query=" + encodeURIComponent(query) + "&dsoId=902"
            httpGet(url, function(status, body) {
                if (status !== 200) {
                    onDone(0, "")
                    return
                }
                var data = JSON.parse(body)
                var target = normalizeText(query)
                var match = null
                for (var i = 0; i < data.length; i++) {
                    if (normalizeText(data[i].value) === target) {
                        match = data[i]
                        break
                    }
                }
                if (!match && data.length > 0) {
                    match = data[0]
                }
                onDone(match ? match.id : 0, match ? match.value : "")
            })
        }

        function refreshFromInputs() {
            var streetQuery = streetField.text.trim()
            var houseQuery = houseField.text.trim()
            clearSchedule()
            if (streetQuery.length < 1 || houseQuery.length < 1) {
                return
            }
            resolveStreetId(streetQuery, function(resolvedStreetId, resolvedStreetValue) {
                if (resolvedStreetId === 0) {
                    return
                }
                page.streetId = resolvedStreetId
                page.streetValue = resolvedStreetValue !== "" ? resolvedStreetValue : streetQuery
                resolveHouseId(resolvedStreetId, houseQuery, function(resolvedHouseId, resolvedHouseValue) {
                    if (resolvedHouseId === 0) {
                        return
                    }
                    page.houseId = resolvedHouseId
                    page.houseValue = resolvedHouseValue !== "" ? resolvedHouseValue : houseQuery
                    page.persistSelection()
                    page.fetchGroupAndOutages()
                })
            })
        }

        function fetchStreets(query) {
            if (query.length < 1) {
                streetModel.clear()
                return
            }
            var url = "https://app.yasno.ua/api/blackout-service/public/shutdowns/addresses/v2/streets" +
                      "?regionId=" + regionId + "&query=" + encodeURIComponent(query) + "&dsoId=902"
            httpGet(url, function(status, body) {
                if (status !== 200) {
                    return
                }
                var data = JSON.parse(body)
                streetModel.clear()
                for (var i = 0; i < data.length; i++) {
                    streetModel.append({ sid: data[i].id, value: data[i].value })
                }
            })
        }

        function fetchHouses(query) {
            if (query.length < 1 || streetId === 0) {
                houseModel.clear()
                return
            }
            var url = "https://app.yasno.ua/api/blackout-service/public/shutdowns/addresses/v2/houses" +
                      "?regionId=" + regionId + "&streetId=" + streetId +
                      "&query=" + encodeURIComponent(query) + "&dsoId=902"
            httpGet(url, function(status, body) {
                if (status !== 200) {
                    return
                }
                var data = JSON.parse(body)
                houseModel.clear()
                for (var i = 0; i < data.length; i++) {
                    houseModel.append({ hid: data[i].id, value: data[i].value })
                }
            })
        }

        function fetchGroupAndOutages() {
            if (regionId === 0 || streetId === 0 || houseId === 0) {
                return
            }
            var url = "https://app.yasno.ua/api/blackout-service/public/shutdowns/addresses/v2/group" +
                      "?regionId=" + regionId + "&streetId=" + streetId + "&houseId=" + houseId + "&dsoId=902"
            httpGet(url, function(status, body) {
                if (status !== 200) {
                    return
                }
                var data = JSON.parse(body)
                groupKey = data.group + "." + data.subgroup
                fetchPlannedOutages()
            })
        }

        function findGroupData(payload, key) {
            if (payload[key]) {
                return payload[key]
            }
            if (payload.groups && payload.groups[key]) {
                return payload.groups[key]
            }
            return null
        }

        function fetchPlannedOutages() {
            if (groupKey === "") {
                return
            }
            var url = "https://app.yasno.ua/api/blackout-service/public/shutdowns/regions/" +
                      regionId + "/dsos/902/planned-outages"
            httpGet(url, function(status, body) {
                if (status !== 200) {
                    return
                }
                var data = JSON.parse(body)
                plannedOutagesPayload = data
                powerNowPercent = computePowerNowPercent(data)
                var groupData = findGroupData(data, groupKey)
                if (!groupData) {
                    return
                }
                updateSchedule(groupData)
                scheduleNextOutageAlarm(groupData)
            })
        }

        function updateSchedule(groupData) {
            var arr = []
            for (var i = 0; i < 48; i++) {
                arr.push(false)
            }
            var dayData = groupData[page.selectedDay]
            if (!dayData || !dayData.slots) {
                outageHalves = arr
                return
            }
            for (var i = 0; i < dayData.slots.length; i++) {
                var slot = dayData.slots[i]
                if (slot.type !== "Definite") {
                    continue
                }
                var startHalf = Math.floor(slot.start / 30)
                var endHalf = Math.ceil(slot.end / 30) - 1
                for (var h = startHalf; h <= endHalf; h++) {
                    if (h >= 0 && h < 48) {
                        arr[h] = true
                    }
                }
            }
            outageHalves = arr
        }

        function formatMinutesAsTime(totalMinutes) {
            var hh = Math.floor(totalMinutes / 60)
            var mm = totalMinutes % 60
            var h = hh < 10 ? "0" + hh : "" + hh
            var m = mm < 10 ? "0" + mm : "" + mm
            return h + ":" + m
        }

        function clearOutageAlarms() {
            if (!alarmModel || alarmModel.count === undefined) {
                return
            }
            for (var i = alarmModel.count - 1; i >= 0; i--) {
                var alarm = alarmModel.get(i)
                if (alarm) {
                    alarm.cancel()
                }
            }
        }

        function scheduleNextOutageAlarm(groupData) {
            if (!notificationsEnabled) {
                clearOutageAlarms()
                return
            }
            if (!alarmModel || !outageAlarm) {
                return
            }
            clearOutageAlarms()
            var dayData = groupData["today"]
            if (!dayData || !dayData.slots) {
                return
            }
            var now = new Date()
            var nowMinutes = now.getHours() * 60 + now.getMinutes()
            var nextStart = -1
            for (var i = 0; i < dayData.slots.length; i++) {
                var slot = dayData.slots[i]
                if (slot.type !== "Definite") {
                    continue
                }
                if (slot.start > nowMinutes && (nextStart < 0 || slot.start < nextStart)) {
                    nextStart = slot.start
                }
            }
            if (nextStart < 0) {
                return
            }
            var alarmMinutes = nextStart - 30
	    if (alarmMinutes < 0) {
	      alarmMinutes += 24 * 60
	    }
            if (alarmMinutes <= nowMinutes) {
                return
            }
            var alarmDate = new Date(now)
            alarmDate.setHours(Math.floor(alarmMinutes / 60))
            alarmDate.setMinutes(alarmMinutes % 60)
            alarmDate.setSeconds(0)
            alarmDate.setMilliseconds(0)

            outageAlarm.reset()
            outageAlarm.type = Alarm.OneTime
            outageAlarm.message = i18n.tr("Через 30 хв буде відключення. Початок о ") +
                                  formatMinutesAsTime(nextStart)
            outageAlarm.sound = ""
            outageAlarm.date = alarmDate
            outageAlarm.save()
        }

        function getCurrentMinutes() {
            var now = new Date()
            return now.getHours() * 60 + now.getMinutes()
        }

        function isOutageNowForGroup(groupData) {
            var dayData = groupData["today"]
            if (!dayData || !dayData.slots) {
                return false
            }
            var minutesNow = getCurrentMinutes()
            for (var i = 0; i < dayData.slots.length; i++) {
                var slot = dayData.slots[i]
                if (slot.type !== "Definite") {
                    continue
                }
                if (minutesNow >= slot.start && minutesNow < slot.end) {
                    return true
                }
            }
            return false
        }

        function computePowerNowPercent(payload) {
            if (!payload) {
                return -1
            }
            var groups = payload.groups ? payload.groups : payload
            if (!groups) {
                return -1
            }
            var keys = Object.keys(groups)
            if (keys.length === 0) {
                return -1
            }
            var total = 0
            var withPower = 0
            for (var i = 0; i < keys.length; i++) {
                var groupData = groups[keys[i]]
                if (!groupData) {
                    continue
                }
                total++
                if (!isOutageNowForGroup(groupData)) {
                    withPower++
                }
            }
            if (total === 0) {
                return -1
            }
            return Math.round(withPower * 100 / total)
        }

        Component.onCompleted: {
            clearSchedule()
            regionId = 25
            regionValue = "Київ"
            citySelector.selectedIndex = 0
            notificationsEnabled = settings.notificationsEnabled
            initAlarms()
            if (settings.regionId === 25 && settings.streetId > 0 && settings.houseId > 0) {
                regionId = settings.regionId
                regionValue = settings.regionValue
                streetId = settings.streetId
                houseId = settings.houseId
                streetValue = settings.streetValue
                houseValue = settings.houseValue
                page.suppressStreetSearch = true
                page.suppressHouseSearch = true
                streetField.text = streetValue
                houseField.text = houseValue
                fetchGroupAndOutages()
            }
        }

        onNotificationsEnabledChanged: {
            settings.notificationsEnabled = notificationsEnabled
            if (!notificationsEnabled) {
                clearOutageAlarms()
                return
            }
            if (plannedOutagesPayload && groupKey !== "") {
                var groupData = findGroupData(plannedOutagesPayload, groupKey)
                if (groupData) {
                    scheduleNextOutageAlarm(groupData)
                }
            }
        }

        function initAlarms() {
            // Create Ubuntu.Components alarms dynamically so desktop qmlscene can run
            if (alarmModel || outageAlarm) {
                return
            }
            if (Qt.platform.os !== "ubuntu") {
                return
            }
            try {
                alarmModel = Qt.createQmlObject(
                    'import Ubuntu.Components 1.3 as Ubuntu; Ubuntu.AlarmModel {}',
                    page,
                    "alarmModel"
                )
                outageAlarm = Qt.createQmlObject(
                    'import Ubuntu.Components 1.3 as Ubuntu; Ubuntu.Alarm {}',
                    page,
                    "outageAlarm"
                )
                outageAlarm.model = alarmModel
            } catch (e) {
                alarmModel = null
                outageAlarm = null
            }
        }

        Timer {
            interval: 60000
            running: true
            repeat: true
            onTriggered: {
                var now = new Date()
                page.currentHour = now.getHours()
                page.currentMinute = now.getMinutes()
            }
        }

        Flickable {
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: units.gu(2)
                rightMargin: units.gu(2)
                bottomMargin: units.gu(2)
                topMargin: units.gu(2)
            }
            contentWidth: width
            contentHeight: contentItem.childrenRect.height
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: units.gu(1)

                Label {
                    text: i18n.tr("Місто")
                    color: "#132430"
                    font.bold: true
                }

                OptionSelector {
                    id: citySelector
                    Layout.fillWidth: true
                    model: ["Київ"]
                    selectedIndex: 0
                    onSelectedIndexChanged: {
                        regionId = 25
                        regionValue = "Київ"
                    }
                }

                Label {
                    text: i18n.tr("Адреса")
                    color: "#132430"
                    font.bold: true
                }

                Item {
                    id: streetBox
                    Layout.fillWidth: true
                    height: units.gu(5)
                    clip: false
                    z: 200

                    Rectangle {
                        anchors.fill: parent
                        radius: units.gu(0.6)
                        color: "#ffffff"
                        border.color: "#007398"
                        border.width: units.dp(1)
                    }

                    TextField {
                        id: streetField
                        anchors.fill: parent
                        anchors.margins: units.gu(0.5)
                        placeholderText: i18n.tr("Вулиця")
                        color: "#132430"
                        style: TextFieldStyle {
                            frameSpacing: 0
                            borderColor: "transparent"
                            backgroundColor: "transparent"
                        }
                        onTextChanged: {
                            if (page.suppressStreetSearch) {
                                page.suppressStreetSearch = false
                                return
                            }
                            page.streetId = 0
                            page.streetValue = ""
                            page.houseId = 0
                            page.houseValue = ""
                            houseField.text = ""
                            houseModel.clear()
                            page.fetchStreets(text)
                        }
                    }

                    Rectangle {
                        id: streetListBox
                        x: 0
                        y: streetBox.height + units.gu(0.5)
                        width: streetBox.width
                        height: Math.min(streetList.contentHeight, units.gu(40))
                        radius: units.gu(0.6)
                        color: "#fff3e0"
                        border.color: "#fb8c00"
                        border.width: units.gu(0.1)
                        visible: streetModel.count > 0
                        z: 210
                        clip: true

                        ListView {
                            id: streetList
                            anchors.fill: parent
                            model: streetModel
                            delegate: ListItem {
                                ListItemLayout {
                                    title.text: model.value
                                    title.color: "#000000"
                                }
                                onClicked: {
                                    page.streetId = model.sid
                                    page.streetValue = model.value
                                    page.suppressStreetSearch = true
                                    streetField.text = model.value
                                    streetModel.clear()
                                    page.houseId = 0
                                    page.houseValue = ""
                                    page.suppressHouseSearch = true
                                    houseField.text = ""
                                    houseModel.clear()
                                    houseField.forceActiveFocus()
                                }
                            }
                        }
                    }
                }

                Label {
                    text: i18n.tr("Будинок")
                    color: "#132430"
                    font.bold: true
                }

                Item {
                    id: houseBox
                    Layout.fillWidth: true
                    height: units.gu(5)
                    clip: false
                    z: 100

                    Rectangle {
                        anchors.fill: parent
                        radius: units.gu(0.6)
                        color: "#ffffff"
                        border.color: "#007398"
                        border.width: units.dp(1)
                    }

                    TextField {
                        id: houseField
                        anchors.fill: parent
                        anchors.margins: units.gu(0.5)
                        placeholderText: i18n.tr("Номер будинку")
                        color: "#132430"
                        style: TextFieldStyle {
                            frameSpacing: 0
                            borderColor: "transparent"
                            backgroundColor: "transparent"
                        }
                        onTextChanged: {
                            if (page.suppressHouseSearch) {
                                page.suppressHouseSearch = false
                                return
                            }
                            page.houseId = 0
                            page.houseValue = ""
                            if (text.length >= 1) {
                                page.fetchHouses(text)
                            } else {
                                houseModel.clear()
                            }
                        }
                    }

                    Rectangle {
                        id: houseListBox
                        x: 0
                        y: houseBox.height + units.gu(0.5)
                        width: houseBox.width
                        height: Math.min(houseList.contentHeight, units.gu(30))
                        radius: units.gu(0.6)
                        color: "#fff3e0"
                        border.color: "#fb8c00"
                        border.width: units.gu(0.1)
                        visible: houseModel.count > 0
                        z: 110
                        clip: true

                        ListView {
                            id: houseList
                            anchors.fill: parent
                            model: houseModel
                            delegate: ListItem {
                                ListItemLayout {
                                    title.text: model.value
                                    title.color: "#000000"
                                }
                                onClicked: {
                                    page.houseId = model.hid
                                    page.houseValue = model.value
                                    page.suppressHouseSearch = true
                                    houseField.text = model.value
                                    houseModel.clear()
                                    page.persistSelection()
                                    page.fetchGroupAndOutages()
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(1)

                    Button {
                        Layout.fillWidth: true
                        text: page.selectedDay === "today" ? i18n.tr("Завтра") : i18n.tr("Сьогодні")
                        onClicked: {
                            page.selectedDay = page.selectedDay === "today" ? "tomorrow" : "today"
                            page.fetchPlannedOutages()
                        }
                    }
                }

                Label {
                    text: page.selectedDay === "today" ? i18n.tr("Графік на сьогодні") : i18n.tr("Графік на завтра")
                    color: "#132430"
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(1)

                    Label {
                        text: i18n.tr("Нагадування за 30 хв")
                        color: "#132430"
                    }

                    Switch {
                        checked: page.notificationsEnabled
                        onCheckedChanged: page.notificationsEnabled = checked
                    }
                }

                Grid {
                    id: scheduleGrid
                    columns: 4
                    rowSpacing: units.gu(0.5)
                    columnSpacing: units.gu(0.5)
                    Layout.fillWidth: true
                    width: parent.width

                    Repeater {
                        model: 24
                        delegate: Rectangle {
                            property bool isCurrentHour: page.selectedDay === "today" && index === page.currentHour && index < 24
                            property bool isOutageFirstHalf: page.outageHalves.length === 48 && page.outageHalves[index * 2]
                            property bool isOutageSecondHalf: page.outageHalves.length === 48 && page.outageHalves[index * 2 + 1]
                            property bool isOutageHour: isOutageFirstHalf || isOutageSecondHalf
                            property bool isFullOutageHour: isOutageFirstHalf && isOutageSecondHalf
                            width: Math.floor((scheduleGrid.width - (scheduleGrid.columns - 1) * scheduleGrid.columnSpacing) / scheduleGrid.columns)
                            height: units.dp(40)
                            radius: units.gu(0.5)
                            color: "#ffffff"
                            border.color: "#007398"
                            border.width: units.dp(1)

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: parent.parent.isOutageFirstHalf ? "#4e5d67" : "transparent"
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: parent.parent.isOutageSecondHalf ? "#4e5d67" : "transparent"
                                }
                            }

                            Label {
                                anchors.centerIn: parent
                                text: index < 10 ? "0" + index : "" + index
                                color: parent.isFullOutageHour ? "#ffffff" : "#132430"
                                font.bold: parent.isCurrentHour || parent.isOutageHour
                            }

                            Rectangle {
                                width: units.dp(6)
                                height: units.dp(6)
                                radius: width / 2
                                color: "#d32f2f"
                                visible: parent.isCurrentHour
                                anchors.top: parent.top
                                anchors.left: parent.isCurrentHour && page.currentMinute < 30 ? parent.left : undefined
                                anchors.right: parent.isCurrentHour && page.currentMinute >= 30 ? parent.right : undefined
                                anchors.margins: units.dp(3)
                            }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: page.powerNowPercent >= 0
                          ? i18n.tr("Зараз зі світлом: ") + page.powerNowPercent + "%"
                          : ""
                    visible: page.powerNowPercent >= 0
                    horizontalAlignment: Text.AlignHCenter
                    color: "#132430"
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                    height: units.gu(6)

                    Rectangle {
                        id: refreshButton
                        width: units.gu(5)
                        height: units.gu(5)
                        radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#fff3e0"
                        border.color: "#fb8c00"
                        border.width: units.gu(0.1)

                        Icon {
                            anchors.centerIn: parent
                            name: "view-refresh"
                            width: units.gu(2.2)
                            height: units.gu(2.2)
                            color: "#132430"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: page.refreshFromInputs()
                        }
                    }
                }
            }
        }
    }
}
