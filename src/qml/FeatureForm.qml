import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Controls.Styles 1.4
import QtGraphicalEffects 1.0
import QtQml.Models 2.11
import QtQml 2.3

import org.qgis 1.0
import org.qfield 1.0
import Theme 1.0

Page {
  signal confirmed
  signal cancelled
  signal temporaryStored
  signal valueChanged(var field, var oldValue, var newValue)
  signal aboutToSave

  property AttributeFormModel model
  property alias toolbarVisible: toolbar.visible
  //! if embedded form called by RelationEditor or RelationReferenceWidget
  property bool embedded: false
  //dontSave means data would be neither saved nor cleared (so feature data is handled elsewhere like e.g. in the tracking)
  property bool dontSave: false
  property bool featureCreated: false

  function reset() {
    master.reset()
  }

  id: form

  states: [
    State {
      name: 'ReadOnly'
    },
    State {
      name: 'Edit'
    },
    State {
      name: 'Add'
    }
  ]

  /**
   * This is a relay to forward private signals to internal components.
   */
  QtObject {
    id: master

    /**
     * This signal is emitted whenever the state of Flickables and TabBars should
     * be restored.
     */
    signal reset
  }

  Item {
    id: container

    clip: true

    anchors {
      top: toolbar.bottom
      bottom: parent.bottom
      left: parent.left
      right: parent.right
    }

    Flickable {
      id: flickable
      anchors {
        left: parent.left
        right: parent.right
      }
      height: tabRow.height

      flickableDirection: Flickable.HorizontalFlick
      contentWidth: tabRow.width

      // Tabs
      TabBar {
        id: tabRow
        visible: model.hasTabs
        height: 48

        Connections {
          target: master
          onReset: tabRow.currentIndex = 0
        }

        Connections {
          target: swipeView
          onCurrentIndexChanged: tabRow.currentIndex = swipeView.currentIndex
        }

        Repeater {
          model: form.model.hasTabs ? form.model : 0

          TabButton {
            id: tabButton
            text: Name
            topPadding: 0
            bottomPadding: 0
            leftPadding: 8
            rightPadding: 8

            width: contentItem.width + leftPadding + rightPadding
            height: 48

            background: Rectangle {
              implicitWidth: parent.width
              implicitHeight: parent.height
              color: "transparent"
            }

            contentItem: Text {
              // Make sure the width is derived from the text so we can get wider
              // than the parent item and the Flickable is useful
              width: paintedWidth
              height: parent.height
              text: tabButton.text
              // color: tabButton.down ? '#17a81a' : '#21be2b'
              color: !tabButton.enabled ? '#999999' : tabButton.down ||
                                        tabButton.checked ? '#1B5E20' : '#4CAF50'
              font.weight: tabButton.checked ? Font.DemiBold : Font.Normal

              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }
      }
    }

    SwipeView {
      id: swipeView
      currentIndex: tabRow.currentIndex
      anchors {
        top: flickable.bottom
        left: parent.left
        right: parent.right
        bottom: parent.bottom
      }

      Repeater {
        // One page per tab in tabbed forms, 1 page in auto forms
        model: form.model.hasTabs ? form.model : 1

        Item {
          id: formPage
          property int currentIndex: index

          Rectangle {
            anchors.fill: formPage
            color: "white"
          }

          /**
           * The main form content area
           */
          ListView {
            id: content
            anchors.fill: parent
            clip: true
            section.property: 'Group'
            section.labelPositioning: ViewSection.CurrentLabelAtStart | ViewSection.InlineLabels
            section.delegate: Component {
              // section header: group box name
              Rectangle {
                width: parent.width
                height: section === "" ? 0 : 30
                color: 'lightGray'

                Text {
                  anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                  width: parent.width
                  font.bold: true
                  text: section
                  wrapMode: Text.WordWrap
                }
              }
            }

            Connections {
              target: master
              onReset: content.contentY = 0
            }

            model: SubModel {
              id: contentModel
              model: form.model
              rootIndex: form.model.hasTabs
                         ? form.model.index(currentIndex, 0)
                         : form.model.index(0, 0)
            }

            delegate: fieldItem
          }
        }
      }
    }
  }

  /**
   * A field editor
   */
  Component {
    id: fieldItem

    Item {
      height: childrenRect.height
      anchors {
        left: parent.left
        right: parent.right
        leftMargin: 12
      }

      Item {
        property string qmlCode: EditorWidgetCode

        id: qmlContainer
        visible: Type == 'qml' && form.model.featureModel.modelMode != FeatureModel.MultiFeatureModel
        height: visible ? childrenRect.height : 0
        anchors {
          left: parent.left
          right: parent.right
        }

        Label {
          id: qmlLabel
          width: parent.width
          text: Name || ''
          wrapMode: Text.WordWrap
          font.pointSize: 12
          font.bold: true
          bottomPadding: 5
          color: 'grey'
        }

        Item {
          id: qmlItem
          height: childrenRect.height
          anchors {
            left: parent.left
            right: parent.right
            top: qmlLabel.bottom
          }
        }

        onQmlCodeChanged: {
          var obj = Qt.createQmlObject(qmlContainer.qmlCode,qmlItem,'qmlContent')
        }
      }

      Item {
        id: fieldContainer
        visible: Type === 'field' || Type === 'relation'
        height: visible ? childrenRect.height : 0
        anchors {
          left: parent.left
          right: parent.right
        }

        Label {
          id: fieldLabel
          width: parent.width
          text: Name || ''
          wrapMode: Text.WordWrap
          font.pointSize: 12
          font.bold: true
          bottomPadding: 5
          color: ConstraintHardValid ? form.state === 'ReadOnly' || embedded && EditorWidget === 'RelationEditor' ? 'grey' : ConstraintSoftValid ? 'black' : Theme.warningColor : Theme.errorColor
        }

        Label {
          id: constraintDescriptionLabel
          anchors {
            left: parent.left
            right: parent.right
            top: fieldLabel.bottom
          }

          font.pointSize: fieldLabel.font.pointSize/3*2
          text: {
            if ( ConstraintHardValid && ConstraintSoftValid )
              return '';

            return ConstraintDescription || '';
          }
          height:  !ConstraintHardValid || !ConstraintSoftValid ? undefined : 0
          visible: !ConstraintHardValid || !ConstraintSoftValid

          color: !ConstraintHardValid ? Theme.errorColor : Theme.darkGray
        }

        Item {
          id: placeholder
          height: childrenRect.height
          anchors { left: parent.left; right: rememberCheckbox.left; top: constraintDescriptionLabel.bottom; rightMargin: 10; }

          Loader {
            id: attributeEditorLoader

            height: childrenRect.height
            anchors { left: parent.left; right: parent.right }

            //disable widget if it's:
            // - not activated in multi edit mode
            // - not set to editable in the widget configuration
            // - not in edit mode (ReadOnly)
            // - a relation in an embedded form or in multi edit mode
            property bool isEnabled: AttributeAllowEdit
                                     && !!AttributeEditable
                                     && form.state !== 'ReadOnly'
                                     && !( Type === 'relation' && ( embedded || form.model.featureModel.modelMode == FeatureModel.MultiFeatureModel ) )
            property var value: AttributeValue
            property var config: ( EditorWidgetConfig || {} )
            property var widget: EditorWidget
            property var field: Field
            property var relationId: RelationId
            property var nmRelationId: NmRelationId
            property var constraintHardValid: ConstraintHardValid
            property var constraintSoftValid: ConstraintSoftValid
            property bool constraintsHardValid: form.model.constraintsHardValid
            property bool constraintsSoftValid: form.model.constraintsSoftValid
            property var currentFeature: form.model.featureModel.feature
            property var currentLayer: form.model.featureModel.currentLayer
            property bool autoSave: qfieldSettings.autoSave
            // TODO investigate why StringUtils are not available in ./editorwidget/*.qml files
            property var stringUtilities: StringUtils

            active: widget !== 'Hidden'
            source: 'editorwidgets/' + ( widget || 'TextEdit' ) + '.qml'

            onStatusChanged: {
              if ( attributeEditorLoader.status === Loader.Error )
              {
                source = 'editorwidgets/TextEdit.qml'
              }
            }
          }

          Connections {
            target: form
            onAboutToSave: {
              // it may not be implemented
              if ( attributeEditorLoader.item.pushChanges ) {
                attributeEditorLoader.item.pushChanges( form.model.featureModel.feature )
              }
            }
            onValueChanged: (field, oldValue, newValue) => {
                              // it may not be implemented
                              if ( attributeEditorLoader.item.siblingValueChanged )
                              attributeEditorLoader.item.siblingValueChanged( field, form.model.featureModel.feature )
                            }
          }

          Connections {
            target: attributeEditorLoader.item
            onValueChanged: {
              if( AttributeValue != value && !( AttributeValue === undefined && isNull ) ) //do not compare AttributeValue and value with strict comparison operators
              {
                var oldValue = AttributeValue
                AttributeValue = isNull ? undefined : value

                valueChanged(Field, oldValue, AttributeValue)

                if ( qfieldSettings.autoSave && !dontSave ) {
                  // indirect action, no need to check for success and display a toast, the log is enough
                  save()
                }
              }
            }
          }
        }

        CheckBox {
          id: rememberCheckbox
          checked: RememberValue ? true : false
          visible: form.state === "Add" && EditorWidget !== "Hidden" && EditorWidget !== 'RelationEditor'
          width: visible ? undefined : 0

          anchors { right: parent.right; top: constraintDescriptionLabel.bottom }

          onCheckedChanged: {
            RememberValue = checked
          }

          indicator.height: 16
          indicator.width: 16
          icon.height: 16
          icon.width: 16
        }

        Label {
          id: multiEditAttributeLabel
          text: (AttributeAllowEdit ? qsTr( "Value applied" ) : qsTr( "Value skipped" ) ) + qsTr( " (click to toggle)" )
          visible: form.model.featureModel.modelMode == FeatureModel.MultiFeatureModel && Type !== 'relation'
          height: form.model.featureModel.modelMode == FeatureModel.MultiFeatureModel ? undefined : 0
          bottomPadding: form.model.featureModel.modelMode == FeatureModel.MultiFeatureModel ? 15 : 0
          anchors { left: parent.left; top: placeholder.bottom;  rightMargin: 10; }
          font: Theme.tipFont
          color: AttributeAllowEdit ? Theme.mainColor : Theme.lightGray

          MouseArea {
            anchors.fill: parent
            onClicked: {
              AttributeAllowEdit = !AttributeAllowEdit
            }
          }
        }
      }
    }
  }

  function confirm() {
    //if this is not handled before (e.g. when this is called because the drawer is closed by tipping on the map)
    if ( !model.constraintsHardValid )
    {
      displayToast( qsTr( 'Constraints not valid') )
      cancel()
      return
    }
    else if ( !model.constraintsSoftValid )
    {
      displayToast( qsTr( 'Note: soft constraints were not met') )
    }

    parent.focus = true

    if( dontSave ) {
      temporaryStored()
      return
    }

    if ( ! save() ) {
      displayToast( qsTr( 'Unable to save changes') )
      state = 'Edit'
      return
    }

    state = 'Edit'

    confirmed()
    featureCreated = false
  }

  function save() {
    if( !model.constraintsHardValid ) {
      return false
    }

    aboutToSave()
    
    var isSuccess = false;

    if( form.state === 'Add' && !featureCreated ) {
      isSuccess = model.create()
      featureCreated = isSuccess
    } else {
      isSuccess = model.save()
    }

    return isSuccess
  }

  function cancel() {
    if( form.state === 'Add' && featureCreated && !qfieldSettings.autoSave ) {
      // indirect action, no need to check for success and display a toast, the log is enough
      model.deleteFeature()
    }
    cancelled()
    featureCreated = false
  }

  Connections {
    target: Qt.inputMethod
    onVisibleChanged: {
      Qt.inputMethod.commit()
    }
  }

  /** The title toolbar **/
  ToolBar {
    id: toolbar
    height: visible ? 48: 0
    visible: form.state === 'Add'

    anchors {
      top: parent.top
      left: parent.left
      right: parent.right
    }

    background: Rectangle {
      color: !model.constraintsHardValid ?  Theme.errorColor : !model.constraintsSoftValid ? Theme.warningColor : Theme.mainColor
    }

    RowLayout {
      anchors.fill: parent
      Layout.margins: 0

      QfToolButton {
        id: saveButton

        Layout.alignment: Qt.AlignTop | Qt.AlignLeft

        visible: ( form.state === 'Add' || form.state === 'Edit' ) && ( !qfieldSettings.autoSave || dontSave )
        width: 48
        height: 48
        clip: true
        bgcolor: Theme.darkGray

        iconSource: model.constraintsHardValid ? Theme.getThemeIcon( "ic_check_white_48dp" ) : Theme.getThemeIcon( "ic_check_gray_48dp" )

        onClicked: {
          if( model.constraintsHardValid ) {
            if ( !model.constraintsSoftValid ) {
              displayToast( qsTr('Note: soft constraints were not met') )
            }
            confirm()
          } else {
            displayToast( qsTr('Constraints not valid') )
          }
        }
      }

      Label {
        id: titleLabel
        leftPadding: model.constraintsHardValid ? 0 : 48

        text:
        {
          var currentLayer = model.featureModel.currentLayer
          var layerName = 'N/A'
          if (currentLayer !== null)
            layerName = currentLayer.name

          if ( form.state === 'Add' )
            qsTr( 'Add feature on %1' ).arg(layerName )
          else if ( form.state === 'Edit' )
            qsTr( 'Edit feature on %1' ).arg(layerName)
          else
            qsTr( 'View feature on %1' ).arg(layerName)
        }
        font: Theme.strongFont
        color: "#FFFFFF"
        elide: Label.ElideRight
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        Layout.fillWidth: true
      }

      QfToolButton {
        id: closeButton

        Layout.alignment: Qt.AlignTop | Qt.AlignRight

        width: 49
        height: 48
        clip: true
        bgcolor: form.state === 'Add' ? "#900000" : Theme.darkGray
        visible: !qfieldSettings.autoSave || dontSave

        iconSource: form.state === 'Add' ? Theme.getThemeIcon( 'ic_delete_forever_white_24dp' ) : Theme.getThemeIcon( 'ic_close_white_24dp' )

        onClicked: {
          Qt.inputMethod.hide()
          cancel()
        }
      }
    }
  }
}
