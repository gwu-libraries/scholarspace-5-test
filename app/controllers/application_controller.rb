# frozen_string_literal: true

class ApplicationController < ActionController::Base
  helper Openseadragon::OpenseadragonHelper
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  include Hydra::Controller::ControllerBehavior

  # Adds Hyrax behaviors into the application controller
  include Hyrax::Controller
  include Hyrax::ThemedLayoutController
  with_themed_layout '1_column'

  protect_from_forgery with: :exception

  # TODO: - this is placeholder and only certain parts seem to be working
  # but this should be the configuration for universal_viewer
  def default_uv_config
    {
      modules: {
        contentLeftPanel: {
          options: {},
          content: {
            autoExpandTreeEnabled: false,
            autoExpandTreeIfFewerThan: 20,
            branchNodesExpandOnClick: true,
            branchNodesSelectable: false,
            defaultToTreeEnabled: false,
            defaultToTreeIfGreaterThan: 0,
            defaultToTreeIfCollection: true,
            expandFullEnabled: true,
            galleryThumbChunkedResizingThreshold: 400,
            galleryThumbHeight: 320,
            galleryThumbLoadPadding: 3,
            galleryThumbWidth: 200,
            oneColThumbHeight: 320,
            oneColThumbWidth: 200,
            pageModeEnabled: true,
            panelAnimationDuration: 250,
            panelCollapsedWidth: 30,
            panelExpandedWidth: 255,
            panelOpen: true,
            tabOrder: '',
            thumbsCacheInvalidation: {
              enabled: true,
              paramType: '?'
            },
            thumbsEnabled: true,
            thumbsExtraHeight: 8,
            thumbsImageFadeInDuration: 300,
            thumbsLoadRange: 15,
            topCloseButtonEnabled: false,
            treeEnabled: true,
            twoColThumbHeight: 150,
            twoColThumbWidth: 90
          }
        },
        searchFooterPanel: {
          content: {},
          options: {
            autocompleteAllowWords: false,
            positionMarkerEnabled: true
          }
        },
        footerPanel: {
          content: {},
          options: {
            shareEnabled: false,
            downloadEnabled: false,
            fullscreenEnabled: false
          }
        },
        pagingHeaderPanel: {
          content: {},
          options: {
            autocompleteAllowWords: false,
            autoCompleteBoxEnabled: false,
            galleryButtonEnabled: false,
            imageSelectionBoxEnabled: false,
            modeOptionsEnabled: true,
            pageModeEnabled: false,
            pagingToggleEnabled: true
          }
        },
        moreInfoRightPanel: {
          content: {
            manifestHeader: nil
          },
          options: {}
        }
      }
    }
  end
end
