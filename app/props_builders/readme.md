# Props builders

Props builders convert application data into props for frontend components.
`WorkShowPropsBuilder` combines a presenter and Rails view context to prepare
metadata, viewer configuration, and file-panel entries for the React
`WorkShow` component. It also includes editing and service-file visibility
information so the interface can present the appropriate controls and files
to each user.
