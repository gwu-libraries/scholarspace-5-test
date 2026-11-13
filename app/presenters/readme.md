# Presenters

Presenters adapt Hyrax records for the application’s views. The custom `WorkShowPresenter` extends Hyrax’s work-show presenter with behavior needed by ScholarSpace’s work page. 

It limits displayed members to authorized files, separates original files from generated service files, and provides transcript data with canvas indexes for the audiovisual viewer. It also caches the assembled work-show props using the work’s modification state and relevant permissions.
