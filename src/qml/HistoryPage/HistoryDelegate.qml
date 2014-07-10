/*
 * Copyright 2012-2013 Canonical Ltd.
 *
 * This file is part of dialer-app.
 *
 * dialer-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * dialer-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Ubuntu.Components 0.1
import Ubuntu.Components.ListItems 0.1 as ListItem
import Ubuntu.Components.Popups 0.1
import Ubuntu.Telephony 0.1
import Ubuntu.Contacts 0.1
import QtContacts 5.0
import "dateUtils.js" as DateUtils

ListItem.Empty {
    id: historyDelegate

    property bool incoming: model.senderId != "self"
    property bool unknownContact: contactWatcher.contactId == ""
    property string phoneNumberSubTypeLabel: ""
    property bool isFirst: false
    property alias contactId: contactWatcher.contactId
    property bool detailsShown: false
    property alias interactive: contactWatcher.interactive
    property alias animating: detailsToggleAnimation.running
    property bool fullView: true

    function activate() {
        if (fullView) {
            mainView.call(model.participants[0], model.accountId);
        } else {
            mainView.populateDialpad(model.participants[0], model.accountId);
        }
    }

    height: mainSection.height + (detailsShown ? pickerLoader.height : 0)
    removable: true
    confirmRemoval: true
    showDivider: true
    clip: true

    states: [
        State {
            name: "basicView"
            when: !fullView
            PropertyChanges {
                target: time
                opacity: 0
            }
            PropertyChanges {
                target: callType
                opacity: 0
            }
        }
    ]
    transitions: [
        Transition {
            UbuntuNumberAnimation {
                properties: "opacity"
            }
        }
    ]

    Behavior on height {
        UbuntuNumberAnimation { id: detailsToggleAnimation }
    }

    onItemRemoved: {
        historyEventModel.removeEvent(model.accountId, model.threadId, model.eventId, model.type)
    }

    function selectCallType()  {
        if (model.callMissed) {
            return i18n.tr("Missed");
        } else if (incoming) {
            return i18n.tr("Incoming");
        } else {
            return i18n.tr("Outgoing");
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: historyDelegate.ListView.isCurrentItem && !fullView ? 0.2 : 0
        Behavior on opacity {
            UbuntuNumberAnimation { }
        }
    }

    Item {
        id: helper
        function updateSubTypeLabel() {
            phoneNumberSubTypeLabel = contactWatcher.isUnknown ? model.participants[0] : phoneTypeModel.get(phoneTypeModel.getTypeIndex(phoneDetail)).label
        }
        Component.onCompleted: updateSubTypeLabel()

        ContactWatcher {
            id: contactWatcher
            // FIXME: handle conf calls
            phoneNumber: model.participants[0]
            onPhoneNumberContextsChanged: helper.updateSubTypeLabel()
            onPhoneNumberSubTypesChanged: helper.updateSubTypeLabel()
            onIsUnknownChanged: helper.updateSubTypeLabel()
        }


        PhoneNumber {
            id: phoneDetail
            contexts: contactWatcher.phoneNumberContexts
            subTypes: contactWatcher.phoneNumberSubTypes
        }

        ContactDetailPhoneNumberTypeModel {
            id: phoneTypeModel
            Component.onCompleted: helper.updateSubTypeLabel()
        }
    }

    Item {
        id: mainSection
        anchors.left: parent.left
        anchors.right: selectionMark.left
        anchors.top: parent.top
        height: units.gu(8)

        ContactAvatar {
            id: avatar
            anchors.left: parent.left
            anchors.leftMargin: units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            height: units.gu(6)
            width: height
            fallbackAvatarUrl: contactWatcher.avatar === "" ? "image://theme/stock_contact" : contactWatcher.avatar
            fallbackDisplayName: contactWatcher.alias !== "" ? contactWatcher.alias : contactWatcher.phoneNumber
            showAvatarPicture: (fallbackAvatarUrl != "image://theme/stock_contact") || (initials.length === 0)
        }

        Label {
            id: titleLabel
            anchors {
                top: parent.top
                topMargin: units.gu(2)
                left: avatar.right
                leftMargin: units.gu(2)
                right: time.left
                rightMargin: units.gu(1)
            }
            height: units.gu(2)
            verticalAlignment: Text.AlignVCenter
            fontSize: "medium"
            text: contactWatcher.alias != "" ? contactWatcher.alias : contactWatcher.phoneNumber
            elide: Text.ElideRight
            color: UbuntuColors.lightAubergine
        }

        Label {
            id: phoneLabel
            anchors {
                bottom: parent.bottom
                bottomMargin: units.gu(2)
                left: avatar.right
                leftMargin: units.gu(2)
            }
            height: units.gu(2)
            verticalAlignment: Text.AlignVCenter
            fontSize: "small"
            // FIXME: handle conference call
            text: phoneNumberSubTypeLabel
            visible: interactive && !contactWatcher.isUnknown // non-interactive entries are calls from unknown or private numbers
        }

        // time and duration on the right side of the delegate
        Label {
            id: time
            anchors {
                right: parent.right
                rightMargin: units.gu(2)
                verticalCenter: titleLabel.verticalCenter
            }
            height: units.gu(2)
            verticalAlignment: Text.AlignVCenter
            fontSize: "small"
            text: Qt.formatTime(model.timestamp, "hh:mm")
        }

        Label {
            id: callType
            anchors {
                right: parent.right
                rightMargin: units.gu(2)
                verticalCenter: phoneLabel.verticalCenter
            }
            height: units.gu(2)
            verticalAlignment: Text.AlignVCenter
            fontSize: "small"
            text: selectCallType()
        }
    }

    Rectangle {
        id: selectionMark

        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }

        color: "black"
        opacity: historyDelegate.selected ? 1.0 : 0.0
        visible: opacity > 0.0
        width: historyDelegate.selected ?  units.gu(5) : 0

        Behavior on opacity {
            UbuntuNumberAnimation { }
        }

        Behavior on width {
            UbuntuNumberAnimation { }
        }

        Icon {
            name: "select"
            height: units.gu(3)
            width: height
            anchors.centerIn: parent
        }
    }

    Loader {
        id: pickerLoader

        source: historyDelegate.detailsShown ? Qt.resolvedUrl("CallLogContactDelegate.qml") : ""
        anchors {
            top: mainSection.bottom
            left: parent.left
            leftMargin: units.gu(2)
            right: parent.right
        }
        onStatusChanged: {
            if (status == Loader.Ready) {
                pickerLoader.item.phoneNumber = participants[0]
                pickerLoader.item.contactId = historyDelegate.contactId
                pickerLoader.item.accountId = accountId
            }
        }
        Connections {
            target: pickerLoader.item
            onItemClicked: historyList.currentContactExpanded = -1
        }
    }
}
